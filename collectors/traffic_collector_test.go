package collectors

import (
	"os"
	"testing"

	"github.com/prometheus/client_golang/prometheus"
	wgc "github.com/tomvil/wanguard_exporter/client"
)

func TestNewTrafficCollector(t *testing.T) {
	wgcClient, err := wgc.NewClient(os.Getenv("TEST_SERVER_URL"), "u", "p")
	if err != nil {
		t.Fatal(err)
	}

	trafficCollector := NewTrafficCollector(wgcClient)
	if trafficCollector == nil {
		t.Error("Expected non-nil collector")
	}
}

func TestTrafficCollectorDescribe(t *testing.T) {
	wgcClient, err := wgc.NewClient(os.Getenv("TEST_SERVER_URL"), "u", "p")
	if err != nil {
		t.Fatal(err)
	}

	trafficCollector := NewTrafficCollector(wgcClient)
	ch := make(chan *prometheus.Desc, 20)
	trafficCollector.Describe(ch)
	close(ch)

	if len(ch) != 20 {
		t.Errorf("Expected 20 metric descriptors, got %d", len(ch))
	}
}
