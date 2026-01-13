package wgc

import (
	"crypto/tls"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/prometheus/client_golang/prometheus"
)

// Client represents the WANGuard API client
type Client struct {
	apiAddress  string
	apiUsername string
	apiPassword string
	httpClient  *http.Client
}

// NewClient creates a new WANGuard API client with security configurations
func NewClient(apiAddress, apiUsername, apiPassword string) (*Client, error) {
	// Validate API address
	parsedURL, err := url.Parse(apiAddress)
	if err != nil {
		return nil, fmt.Errorf("invalid API address: %w", err)
	}

	if parsedURL.Scheme != "http" && parsedURL.Scheme != "https" {
		return nil, errors.New("API address must use http or https")
	}

	if parsedURL.Host == "" {
		return nil, errors.New("API address must include host")
	}

	// Security: Block HTTP for non-localhost to prevent credential leakage
	if parsedURL.Scheme == "http" {
		host := parsedURL.Hostname()
		if host != "localhost" && host != "127.0.0.1" && host != "::1" {
			return nil, fmt.Errorf("HTTP is not allowed for remote hosts (use HTTPS): %s", host)
		}
	}

	// Configure secure HTTP client
	httpClient := &http.Client{
		Timeout: 30 * time.Second,
		Transport: &http.Transport{
			MaxIdleConns:          10,
			MaxIdleConnsPerHost:   5,
			IdleConnTimeout:       30 * time.Second,
			TLSHandshakeTimeout:   10 * time.Second,
			ResponseHeaderTimeout: 10 * time.Second,
			DisableCompression:    false,
			TLSClientConfig: &tls.Config{
				MinVersion:         tls.VersionTLS12,
				InsecureSkipVerify: false,
			},
		},
		// Prevent credential leaks via redirects
		CheckRedirect: func(req *http.Request, via []*http.Request) error {
			if len(via) >= 10 {
				return errors.New("stopped after 10 redirects")
			}
			// Only allow HTTPS for redirects
			if req.URL.Scheme != "https" {
				return errors.New("HTTPS required for redirects")
			}
			// Do not forward credentials on cross-origin redirects
			if req.URL.Host != via[0].URL.Host {
				// Remove Authorization header
				req.Header.Del("Authorization")
			}
			return nil
		},
	}

	return &Client{
		apiAddress:  apiAddress,
		apiUsername: apiUsername,
		apiPassword: apiPassword,
		httpClient:  httpClient,
	}, nil
}

// basicAuth generates Basic Authentication header
func basicAuth(username, password string) string {
	creds := username + ":" + password
	return base64.StdEncoding.EncodeToString([]byte(creds))
}

// Get performs an HTTP GET request to the WANGuard API
func (c *Client) Get(path string) ([]byte, error) {
	fullPath := c.apiAddress + path
	if !strings.Contains(path, "/wanguard-api/v1/") {
		fullPath = c.apiAddress + "/wanguard-api/v1/" + path
	}

	req, err := http.NewRequest("GET", fullPath, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	req.SetBasicAuth(c.apiUsername, c.apiPassword)

	resp, err := c.httpClient.Do(req)
	if err != nil {
		// Update API up metric on error
		wanguardAPIUp.WithLabelValues(c.apiAddress).Set(0)
		return nil, fmt.Errorf("HTTP request failed: %w", err)
	}
	defer resp.Body.Close()

	// Update API up metric based on status code
	if resp.StatusCode >= 200 && resp.StatusCode < 300 {
		wanguardAPIUp.WithLabelValues(c.apiAddress).Set(1)
	} else {
		wanguardAPIUp.WithLabelValues(c.apiAddress).Set(0)
	}

	// Validate status code
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return nil, fmt.Errorf("API returned status %d", resp.StatusCode)
	}

	// Validate content type
	contentType := resp.Header.Get("Content-Type")
	if contentType != "" && !strings.Contains(contentType, "application/json") {
		return nil, fmt.Errorf("expected JSON response, got %s", contentType)
	}

	// Limit response body to 10MB to prevent DoS via unbounded memory allocation
	const maxResponseSize = 10 * 1024 * 1024 // 10MB
	body, err := io.ReadAll(io.LimitReader(resp.Body, maxResponseSize))
	if err != nil {
		return nil, fmt.Errorf("failed to read response body: %w", err)
	}

	return body, nil
}

// GetParsed performs an HTTP GET request and parses the JSON response
func (c *Client) GetParsed(path string, obj interface{}) error {
	body, err := c.Get(path)
	if err != nil {
		return err
	}

	err = json.Unmarshal(body, obj)
	if err != nil {
		return fmt.Errorf("failed to parse JSON response: %w", err)
	}

	return nil
}

// Metric to track WANGuard API availability
var (
	wanguardAPIUp = prometheus.NewGaugeVec(
		prometheus.GaugeOpts{
			Name: "wanguard_api_up",
			Help: "Whether the WANGuard API is reachable (1 = up, 0 = down)",
		},
		[]string{"api_address"},
	)
)

// InitMetrics initializes the API metrics and returns the metric
func InitMetrics() *prometheus.GaugeVec {
	return wanguardAPIUp
}
