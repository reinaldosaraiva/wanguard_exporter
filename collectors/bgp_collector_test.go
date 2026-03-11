package collectors

import (
	"os"
	"testing"

	"github.com/prometheus/client_golang/prometheus"
	wgc "github.com/tomvil/wanguard_exporter/client"
)

func TestNewBGPCollector(t *testing.T) {
	wgcClient, err := wgc.NewClient(os.Getenv("TEST_SERVER_URL"), "u", "p", false)
	if err != nil {
		t.Fatal(err)
	}

	bgpCollector := NewBGPCollector(wgcClient)
	if bgpCollector == nil {
		t.Error("Expected non-nil collector")
	}
}

func TestBGPCollectorDescribe(t *testing.T) {
	wgcClient, err := wgc.NewClient(os.Getenv("TEST_SERVER_URL"), "u", "p", false)
	if err != nil {
		t.Fatal(err)
	}

	bgpCollector := NewBGPCollector(wgcClient)
	ch := make(chan *prometheus.Desc, 1)
	bgpCollector.Describe(ch)
	close(ch)

	if len(ch) != 1 {
		t.Errorf("Expected 1 metric descriptor, got %d", len(ch))
	}
}

func TestBGPCollectorCollect(t *testing.T) {
	wgcClient, err := wgc.NewClient(os.Getenv("TEST_SERVER_URL"), "u", "p", false)
	if err != nil {
		t.Fatal(err)
	}

	bgpCollector := NewBGPCollector(wgcClient)
	ch := make(chan prometheus.Metric, 10)
	bgpCollector.Collect(ch)
	close(ch)

	metrics := make([]prometheus.Metric, 0)
	for m := range ch {
		metrics = append(metrics, m)
	}

	if len(metrics) != 1 {
		t.Errorf("Expected 1 metric, got %d", len(metrics))
	}
}
