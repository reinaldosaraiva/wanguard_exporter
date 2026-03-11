package collectors

import (
	"github.com/tomvil/wanguard_exporter/logging"

	"github.com/prometheus/client_golang/prometheus"
	wgc "github.com/tomvil/wanguard_exporter/client"
)

type BGPCollector struct {
	wgClient    *wgc.Client
	ConnectorUp *prometheus.Desc
}

type BGPConnectorList struct {
	BGPConnectorId   string `json:"bgp_connector_id"`
	BGPConnectorName string `json:"bgp_connector_name"`
	Href             string `json:"href"`
}

type BGPConnectorDetail struct {
	BGPConnectorId   string `json:"bgp_connector_id"`
	BGPConnectorName string `json:"bgp_connector_name"`
	ConnectorRole    string `json:"connector_role"`
	DeviceGroup      string `json:"device_group"`
	BGPFlowspec      string `json:"bgp_flowspec"`
	Status           struct {
		Href string `json:"href"`
	} `json:"status"`
}

func NewBGPCollector(wgclient *wgc.Client) *BGPCollector {
	prefix := "wanguard_bgp_connector_"
	return &BGPCollector{
		wgClient:    wgclient,
		ConnectorUp: prometheus.NewDesc(prefix+"up", "BGP connector status (1=Active, 0=Down)", []string{"connector_name", "connector_id", "connector_role", "device_group", "flowspec"}, nil),
	}
}

func (c *BGPCollector) Describe(ch chan<- *prometheus.Desc) {
	ch <- c.ConnectorUp
}

func (c *BGPCollector) Collect(ch chan<- prometheus.Metric) {
	var connectors []BGPConnectorList

	err := c.wgClient.GetParsed("bgp_connectors", &connectors)
	if err != nil {
		logging.Error("BGP collector: error fetching connector list: %v", err)
		return
	}

	for _, connector := range connectors {
		// Get detail (includes role, device_group, flowspec)
		var detail BGPConnectorDetail
		err := c.wgClient.GetParsed(connector.Href, &detail)
		if err != nil {
			logging.Error("BGP collector: error fetching detail for %s: %v", connector.BGPConnectorName, err)
			continue
		}

		// Get status
		var status map[string]string
		err = c.wgClient.GetParsed(detail.Status.Href, &status)
		if err != nil {
			logging.Error("BGP collector: error fetching status for %s: %v", connector.BGPConnectorName, err)
			ch <- prometheus.MustNewConstMetric(c.ConnectorUp, prometheus.GaugeValue, 0,
				detail.BGPConnectorName,
				detail.BGPConnectorId,
				detail.ConnectorRole,
				detail.DeviceGroup,
				detail.BGPFlowspec)
			continue
		}

		value := 0.0
		if status["status"] == "Active" {
			value = 1.0
		}

		ch <- prometheus.MustNewConstMetric(c.ConnectorUp, prometheus.GaugeValue, value,
			detail.BGPConnectorName,
			detail.BGPConnectorId,
			detail.ConnectorRole,
			detail.DeviceGroup,
			detail.BGPFlowspec)
	}
}
