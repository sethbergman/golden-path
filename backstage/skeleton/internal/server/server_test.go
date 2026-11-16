package server

import (
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func newTest(t *testing.T) (*Server, *httptest.Server) {
	t.Helper()
	s := New(slog.New(slog.NewTextHandler(io.Discard, nil)), "test")
	ts := httptest.NewServer(s.Handler())
	t.Cleanup(ts.Close)
	return s, ts
}

func get(t *testing.T, url string) (int, string) {
	t.Helper()
	resp, err := http.Get(url)
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	b, _ := io.ReadAll(resp.Body)
	return resp.StatusCode, string(b)
}

func TestHello(t *testing.T) {
	_, ts := newTest(t)
	code, body := get(t, ts.URL+"/hello?name=platform")
	if code != http.StatusOK {
		t.Fatalf("status %d", code)
	}
	var out map[string]string
	if err := json.Unmarshal([]byte(body), &out); err != nil {
		t.Fatal(err)
	}
	if out["message"] != "hello, platform" || out["version"] != "test" {
		t.Fatalf("unexpected body %v", out)
	}

	if _, body := get(t, ts.URL+"/hello"); !strings.Contains(body, "hello, world") {
		t.Fatalf("default name missing: %s", body)
	}
	if code, _ := get(t, ts.URL+"/hello?name="+strings.Repeat("x", 65)); code != http.StatusBadRequest {
		t.Fatalf("long name status %d, want 400", code)
	}
}

func TestProbes(t *testing.T) {
	s, ts := newTest(t)
	if code, _ := get(t, ts.URL+"/healthz"); code != http.StatusOK {
		t.Fatalf("healthz %d", code)
	}
	if code, _ := get(t, ts.URL+"/readyz"); code != http.StatusServiceUnavailable {
		t.Fatalf("readyz before ready = %d, want 503", code)
	}
	s.SetReady(true)
	if code, _ := get(t, ts.URL+"/readyz"); code != http.StatusOK {
		t.Fatalf("readyz after ready = %d", code)
	}
}

func TestMetricsUseRoutePatterns(t *testing.T) {
	_, ts := newTest(t)
	get(t, ts.URL+"/hello?name=a")
	get(t, ts.URL+"/hello?name=b")
	get(t, ts.URL+"/nope")
	_, body := get(t, ts.URL+"/metrics")

	for _, want := range []string{
		`http_requests_total{method="GET",route="GET /hello",code="200"} 2`,
		`route="unmatched",code="404"`,
		`build_info{version="test"} 1`,
	} {
		if !strings.Contains(body, want) {
			t.Errorf("metrics missing %q\n%s", want, body)
		}
	}
	if strings.Contains(body, "name=a") {
		t.Error("query strings leaked into metric labels")
	}
}
