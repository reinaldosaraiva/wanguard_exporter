package collectors

import (
	"os"
	"testing"

	"github.com/prometheus/client_golang/prometheus"
	wgc "github.com/tomvil/wanguard_exporter/client"
)

func TestNewAnnouncementsCollector(t *testing.T) {
	wgcClient, err := wgc.NewClient(os.Getenv("TEST_SERVER_URL", false), "u", "p")
	if err != nil {
		t.Fatal(err)
	}

	announcementsCollector := NewAnnouncementsCollector(wgcClient)
	if announcementsCollector == nil {
		t.Error("Expected non-nil collector")
	}
}

func TestAnnouncementsCollectorDescribe(t *testing.T) {
	wgcClient, err := wgc.NewClient(os.Getenv("TEST_SERVER_URL", false), "u", "p")
	if err != nil {
		t.Fatal(err)
	}

	announcementsCollector := NewAnnouncementsCollector(wgcClient)
	ch := make(chan *prometheus.Desc, 2)
	announcementsCollector.Describe(ch)
	close(ch)

	if len(ch) != 2 {
		t.Errorf("Expected 2 metric descriptors, got %d", len(ch))
	}
}
