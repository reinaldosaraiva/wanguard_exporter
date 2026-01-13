package collectors

import (
	"os"
	"testing"

	"github.com/prometheus/client_golang/prometheus"
	wgc "github.com/tomvil/wanguard_exporter/client"
)

func TestNewAnomaliesCollector(t *testing.T) {
	wgcClient, err := wgc.NewClient(os.Getenv("TEST_SERVER_URL"), "u", "p")
	if err != nil {
		t.Fatal(err)
	}

	anomaliesCollector := NewAnomaliesCollector(wgcClient)
	if anomaliesCollector == nil {
		t.Error("Expected non-nil collector")
	}
}

func TestAnomaliesCollectorDescribe(t *testing.T) {
	wgcClient, err := wgc.NewClient(os.Getenv("TEST_SERVER_URL"), "u", "p")
	if err != nil {
		t.Fatal(err)
	}

	anomaliesCollector := NewAnomaliesCollector(wgcClient)
	ch := make(chan *prometheus.Desc, 2)
	anomaliesCollector.Describe(ch)
	close(ch)

	if len(ch) != 2 {
		t.Errorf("Expected 2 metric descriptors, got %d", len(ch))
	}
}
