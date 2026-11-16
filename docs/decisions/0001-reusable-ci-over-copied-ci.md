# 0001: Reusable workflows and CI components instead of copied pipeline files

- Status: accepted
- Date: 2026-11-15

## Context

Services commonly start by copying another team's pipeline. Copies drift: security fixes, new scanners and faster caching have to be applied repo by repo, and most never get them.

## Decision

Pipeline logic lives here, as GitHub reusable workflows and GitLab CI/CD components. Service repos keep a few lines that call them at a pinned version.

## Consequences

- One fix here reaches every service at its next upgrade.
- Teams can still add their own jobs alongside; they cannot silently weaken the shared ones.
- The golden path needs real release discipline (see docs/versioning.md), because a bad release affects many repos at once. CI tests every change against an example service and a freshly generated one to keep that risk low.
