package collectors

import (
	"github.com/tomvil/wanguard_exporter/logging"

	"strconv"

	"github.com/prometheus/client_golang/prometheus"
	wgc "github.com/tomvil/wanguard_exporter/client"
)

type AnnouncementsCollector struct {
	wgClient              *wgc.Client
	AnnouncementActive    *prometheus.Desc
	AnnouncementsFinished *prometheus.Desc
}

type AnnouncementCount struct {
	Count string
}

func NewAnnouncementsCollector(wgclient *wgc.Client) *AnnouncementsCollector {
	prefix := "wanguard_announcement"

	return &AnnouncementsCollector{
		wgClient:              wgclient,
		AnnouncementActive:    prometheus.NewDesc(prefix+"active", "Active announcements", []string{"announcement_name"}, nil),
		AnnouncementsFinished: prometheus.NewDesc(prefix+"finished", "Finished announcements", []string{"announcement_name"}, nil),
	}
}

func (c *AnnouncementsCollector) Describe(ch chan<- *prometheus.Desc) {
	ch <- c.AnnouncementActive
	ch <- c.AnnouncementsFinished
}

func (c *AnnouncementsCollector) Collect(ch chan<- prometheus.Metric) {
	var announcements []AnnouncementCount

	err := c.wgClient.GetParsed("announcements?count=true", &announcements)
	if err != nil {
		logging.Error("Error: %v", err)
		return
	}

	for _, announcement := range announcements {
		var finishedAnnouncement AnnouncementCount

		err := c.wgClient.GetParsed("announcements/"+announcement.Count+"/finished", &finishedAnnouncement)
		if err != nil {
			continue
		}

		activeCount, err := strconv.ParseFloat(announcement.Count, 64)
		if err != nil {
			logging.Error("Error: %v", err)
			ch <- prometheus.MustNewConstMetric(c.AnnouncementActive, prometheus.GaugeValue, 0, announcement.Count)
			continue
		}

		finishedCount, err := strconv.ParseFloat(finishedAnnouncement.Count, 64)
		if err != nil {
			logging.Error("Error: %v", err)
			ch <- prometheus.MustNewConstMetric(c.AnnouncementsFinished, prometheus.GaugeValue, 0, announcement.Count)
			continue
		}

		ch <- prometheus.MustNewConstMetric(c.AnnouncementActive, prometheus.GaugeValue, activeCount, announcement.Count)
		ch <- prometheus.MustNewConstMetric(c.AnnouncementsFinished, prometheus.GaugeValue, finishedCount, announcement.Count)
	}
}
