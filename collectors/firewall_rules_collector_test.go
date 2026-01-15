package collectors

import (
	"os"
	"testing"

	"github.com/prometheus/client_golang/prometheus"
	wgc "github.com/tomvil/wanguard_exporter/client"
)

func TestNewFirewallRulesCollector(t *testing.T) {
	wgcClient, err := wgc.NewClient(os.Getenv("TEST_SERVER_URL", false), "u", "p")
	if err != nil {
		t.Fatal(err)
	}

	firewallRulesCollector := NewFirewallRulesCollector(wgcClient)
	if firewallRulesCollector == nil {
		t.Error("Expected non-nil collector")
	}
}

func TestFirewallRulesCollectorDescribe(t *testing.T) {
	wgcClient, err := wgc.NewClient(os.Getenv("TEST_SERVER_URL", false), "u", "p")
	if err != nil {
		t.Fatal(err)
	}

	firewallRulesCollector := NewFirewallRulesCollector(wgcClient)
	ch := make(chan *prometheus.Desc, 1)
	firewallRulesCollector.Describe(ch)
	close(ch)

	if len(ch) != 1 {
		t.Errorf("Expected 1 metric descriptor, got %d", len(ch))
	}
}
