# 0003: Deploy images by digest

- Status: accepted
- Date: 2026-11-15

## Context

Tags can be moved, and a tag that CI tested may not be what a cluster later pulls. Even with immutable tags in ECR, a tag is one lookup away from the bytes that run.

## Decision

The container workflow and component output the pushed image digest, and deploys set `image.digest`, which the chart prefers over the tag.

## Consequences

- Production runs exactly the image that was built, scanned and tested.
- Rollback means redeploying an earlier digest, which is recorded in the deploy history.
- Humans read tags, not digests, so the chart keeps the tag as the `app.kubernetes.io/version` label for dashboards.
