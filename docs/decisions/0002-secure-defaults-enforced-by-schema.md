# 0002: Secure defaults in the chart, enforced by a values schema

- Status: accepted
- Date: 2026-11-15

## Context

A chart with secure defaults still lets a values file turn them off, and review rarely catches it.

## Decision

Security settings that no golden-path service should change (non-root, read-only root filesystem, dropped capabilities, seccomp) are not configurable at all. Choices that are usually wrong (`latest` tags, a single autoscaled replica, `LoadBalancer` services, no owner) are rejected by `values.schema.json`, so `helm install` fails before anything reaches the cluster.

## Consequences

- Mistakes are caught at install time, with a clear message, rather than in an audit.
- A service with a real need for an exception uses its own manifests (see docs/adopting.md), which makes exceptions visible instead of hidden in values.
- CI tests the rejections explicitly, so a future change cannot quietly loosen them.
