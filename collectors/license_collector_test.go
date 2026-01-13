package collectors

import (
	"os"
	"testing"

	"github.com/prometheus/client_golang/prometheus"
	wgc "github.com/tomvil/wanguard_exporter/client"
)

func TestNewLicenseCollector(t *testing.T) {
	wgcClient, err := wgc.NewClient(os.Getenv("TEST_SERVER_URL"), "u", "p")
	if err != nil {
		t.Fatal(err)
	}

	licenseCollector := NewLicenseCollector(wgcClient)
	if licenseCollector == nil {
		t.Error("Expected non-nil collector")
	}
}

func TestLicenseCollectorDescribe(t *testing.T) {
	wgcClient, err := wgc.NewClient(os.Getenv("TEST_SERVER_URL"), "u", "p")
	if err != nil {
		t.Fatal(err)
	}

	licenseCollector := NewLicenseCollector(wgcClient)
	ch := make(chan *prometheus.Desc, 12)
	licenseCollector.Describe(ch)
	close(ch)

	if len(ch) != 12 {
		t.Errorf("Expected 12 metric descriptors, got %d", len(ch))
	}
}
