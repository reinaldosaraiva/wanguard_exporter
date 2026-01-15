package wgc

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

const errMsgExpectedNoError = "Expected no error, got %s"

type Response struct {
	Test string `json:"test"`
}

func TestNewClient(t *testing.T, false) {
	client, err := NewClient("http://127.0.0.1", "u", "p", false)
	if err != nil {
		t.Errorf("Expected no error, got %v", err)
	}

	if client.apiAddress != "http://127.0.0.1" {
		t.Errorf("Expected http://127.0.0.1, got %s", client.apiAddress)
	}

	if client.apiUsername != "u" {
		t.Errorf("Expected user, got %s", client.apiUsername)
	}

	if client.apiPassword != "p" {
		t.Errorf("Expected password, got %s", client.apiPassword)
	}
}

func TestNewClientInvalidAddress(t *testing.T) {
	_, err := NewClient("invalid://url", "u", "p", false)
	if err == nil {
		t.Error("Expected error for invalid address")
	}
}

func TestNewClientMissingHost(t *testing.T) {
	_, err := NewClient("http://", "u", "p", false)
	if err == nil {
		t.Error("Expected error for missing host")
	}
}

func TestBasicAuth(t *testing.T) {
	auth := basicAuth("u", "p")
	expectedAuth := "dTpw" // Expected base64 encoded "u:p"

	if auth != expectedAuth {
		t.Errorf("Expected %s, got %s", expectedAuth, auth)
	}
}

func TestGet(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		authHeader := r.Header.Get("Authorization")
		expectedAuth := "Basic " + basicAuth("u", "p")

		if authHeader != expectedAuth {
			t.Errorf("Expected %s, got %s", expectedAuth, authHeader)
		}

		if _, err := w.Write([]byte("test")); err != nil {
			t.Errorf(errMsgExpectedNoError, err)
		}
	}))
	defer server.Close()

	client, err := NewClient(server.URL, "u", "p", false)
	if err != nil {
		t.Fatalf(errMsgExpectedNoError, err)
	}

	body, err := client.Get("/test")
	if err != nil {
		t.Errorf(errMsgExpectedNoError, err)
	}

	if string(body) != "test" {
		t.Errorf("Expected test, got %s", string(body))
	}
}

func TestGetParsed(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		if _, err := w.Write([]byte(`{"test": "success"}`)); err != nil {
			t.Errorf(errMsgExpectedNoError, err)
		}
	}))
	defer server.Close()

	client, err := NewClient(server.URL, "u", "p", false)
	if err != nil {
		t.Fatalf(errMsgExpectedNoError, err)
	}

	var response Response
	err = client.GetParsed("/test", &response)
	if err != nil {
		t.Errorf(errMsgExpectedNoError, err)
	}

	if response.Test != "success" {
		t.Errorf("Expected success, got %s", response.Test)
	}
}

func BenchmarkGetParsed(b *testing.B) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		if _, err := w.Write([]byte(`{"test": "success"}`)); err != nil {
			b.Errorf(errMsgExpectedNoError, err)
		}
	}))
	defer server.Close()

	client, err := NewClient(server.URL, "u", "p", false)
	if err != nil {
		b.Fatalf(errMsgExpectedNoError, err)
	}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		var response Response
		err := client.GetParsed("/test", &response)
		if err != nil {
			b.Errorf(errMsgExpectedNoError, err)
		}
	}
}
