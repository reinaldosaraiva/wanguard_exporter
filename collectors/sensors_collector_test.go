package collectors

import (
	"os"
	"testing"

	"github.com/prometheus/client_golang/prometheus"
	wgc "github.com/tomvil/wanguard_exporter/client"
)

func TestNewSensorsCollector(t *testing.T) {
	wgcClient, err := wgc.NewClient(os.Getenv("TEST_SERVER_URL"), "u", "p", false)
	if err != nil {
		t.Fatal(err)
	}

	sensorsCollector := NewSensorsCollector(wgcClient)
	if sensorsCollector == nil {
		t.Error("Expected non-nil collector")
	}
}

func TestSensorsCollectorDescribe(t *testing.T) {
	wgcClient, err := wgc.NewClient(os.Getenv("TEST_SERVER_URL"), "u", "p", false)
	if err != nil {
		t.Fatal(err)
	}

	sensorsCollector := NewSensorsCollector(wgcClient)
	ch := make(chan *prometheus.Desc, 20)
	sensorsCollector.Describe(ch)
	close(ch)

	if len(ch) != 13 {
		t.Errorf("Expected 13 metric descriptors, got %d", len(ch))
	}
}
