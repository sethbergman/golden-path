// Package server is the HTTP surface every golden-path service starts with:
// a business endpoint, health and readiness probes, Prometheus metrics, and
// request logging. Teams replace the business endpoint and keep the rest.
package server

import (
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"strings"
	"sync"
	"sync/atomic"
	"time"
)

// Server holds request metrics and readiness state.
type Server struct {
	log     *slog.Logger
	version string
	ready   atomic.Bool

	mu        sync.Mutex
	requests  map[string]uint64 // "METHOD path status" -> count
	durations map[string]float64
}

// New returns a Server. It starts not ready; call SetReady once dependencies
// are reachable.
func New(log *slog.Logger, version string) *Server {
	return &Server{
		log:       log,
		version:   version,
		requests:  map[string]uint64{},
		durations: map[string]float64{},
	}
}

// SetReady flips the readiness probe.
func (s *Server) SetReady(v bool) { s.ready.Store(v) }

// Handler returns the routed, instrumented handler.
func (s *Server) Handler() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /hello", s.hello)
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte("ok\n"))
	})
	mux.HandleFunc("GET /readyz", func(w http.ResponseWriter, _ *http.Request) {
		if !s.ready.Load() {
			http.Error(w, "not ready", http.StatusServiceUnavailable)
			return
		}
		_, _ = w.Write([]byte("ready\n"))
	})
	mux.HandleFunc("GET /metrics", s.metrics)
	return s.instrument(mux)
}

func (s *Server) hello(w http.ResponseWriter, r *http.Request) {
	name := strings.TrimSpace(r.URL.Query().Get("name"))
	if name == "" {
		name = "world"
	}
	if len(name) > 64 {
		http.Error(w, "name too long", http.StatusBadRequest)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]string{
		"message": "hello, " + name,
		"version": s.version,
	})
}

type statusRecorder struct {
	http.ResponseWriter
	status int
}

func (r *statusRecorder) WriteHeader(code int) {
	r.status = code
	r.ResponseWriter.WriteHeader(code)
}

func (s *Server) instrument(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		rec := &statusRecorder{ResponseWriter: w, status: http.StatusOK}
		next.ServeHTTP(rec, r)
		took := time.Since(start)

		// Label by route pattern, not raw path, to keep cardinality bounded.
		route := r.Pattern
		if route == "" {
			route = "unmatched"
		}
		key := fmt.Sprintf("%s\x00%s\x00%d", r.Method, route, rec.status)
		s.mu.Lock()
		s.requests[key]++
		s.durations[key] += took.Seconds()
		s.mu.Unlock()

		if route != "GET /healthz" && route != "GET /readyz" && route != "GET /metrics" {
			s.log.Info("request", "method", r.Method, "route", route, "status", rec.status,
				"duration_ms", float64(took.Microseconds())/1000)
		}
	})
}

func (s *Server) metrics(w http.ResponseWriter, _ *http.Request) {
	w.Header().Set("Content-Type", "text/plain; version=0.0.4; charset=utf-8")
	s.mu.Lock()
	defer s.mu.Unlock()
	fmt.Fprint(w, "# HELP http_requests_total Requests by method, route and status.\n# TYPE http_requests_total counter\n")
	for k, n := range s.requests {
		m, route, code := split(k)
		fmt.Fprintf(w, "http_requests_total{method=%q,route=%q,code=%q} %d\n", m, route, code, n)
	}
	fmt.Fprint(w, "# HELP http_request_duration_seconds_sum Total time spent serving requests.\n# TYPE http_request_duration_seconds_sum counter\n")
	for k, d := range s.durations {
		m, route, code := split(k)
		fmt.Fprintf(w, "http_request_duration_seconds_sum{method=%q,route=%q,code=%q} %g\n", m, route, code, d)
	}
	fmt.Fprintf(w, "# HELP build_info Build version.\n# TYPE build_info gauge\nbuild_info{version=%q} 1\n", s.version)
}

func split(key string) (method, route, code string) {
	parts := strings.SplitN(key, "\x00", 3)
	return parts[0], parts[1], parts[2]
}
