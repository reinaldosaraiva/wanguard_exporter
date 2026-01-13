package collectors

import (
	"strconv"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/tomvil/wanguard_exporter/logging"
	wgc "github.com/tomvil/wanguard_exporter/client"
)

type FirewallRulesCollector struct {
	wgClient           *wgc.Client
	FirewallRuleActive *prometheus.Desc
}

type FirewallRulesCount struct {
	Count string
}

func NewFirewallRulesCollector(wgclient *wgc.Client) *FirewallRulesCollector {
	prefix := "wanguard_firewall_rule_"
	return &FirewallRulesCollector{
		wgClient:           wgclient,
		FirewallRuleActive: prometheus.NewDesc(prefix+"active", "Active firewall rules", []string{"firewall_rule_name"}, nil),
	}
}

func (c *FirewallRulesCollector) Describe(ch chan<- *prometheus.Desc) {
	ch <- c.FirewallRuleActive
}

func (c *FirewallRulesCollector) Collect(ch chan<- prometheus.Metric) {
	var firewallRulesCount FirewallRulesCount

	err := c.wgClient.GetParsed("firewall_rules?count=true", &firewallRulesCount)
	if err != nil {
		logging.Error("Error: %v", err)
		return
	}

	rulesCount, err := strconv.ParseFloat(firewallRulesCount.Count, 64)
	if err != nil {
		logging.Error("Error: %v", err)
		ch <- prometheus.MustNewConstMetric(c.FirewallRuleActive, prometheus.GaugeValue, 0)
		return
	}

	ch <- prometheus.MustNewConstMetric(c.FirewallRuleActive, prometheus.GaugeValue, rulesCount)
}
