# Adopting the golden path

## For a new service

1. In Backstage, choose **Create → Go service (golden path)**.
2. Name it, pick the owning team, choose the repository location.
3. Backstage creates the repo, registers it in the catalog, and the first CI run tests, builds, scans and pushes an image.
4. Apply the AWS baseline for it (`terraform/modules/service-baseline`) and copy two outputs into `deploy/values.yaml`: `repository_url` into `image.repository`, `role_arn` into the service account annotation.

## For an existing service

Adopt in this order. Each step stands alone and is worth it on its own.

| Step | Change | What you get |
|---|---|---|
| 1. CI | Call `reusable-go.yml` (or include the `go` component) | Consistent tests with the race detector and coverage. |
| 2. Image | Switch to `docker/go/Dockerfile` and `reusable-container.yml` | Distroless non-root image, SBOM, provenance, vulnerability gate, digest output. |
| 3. Deploy | Move to `charts/service` with a `deploy/values.yaml` | Secure pod defaults, HPA, PDB, spreading, network policy. |
| 4. AWS | Replace hand-made ECR repos and roles with `service-baseline` | Immutable tags, image expiry, no long-lived CI keys. |
| 5. Catalog | Add `catalog-info.yaml` | Ownership, docs and links in Backstage. |

## When the golden path does not fit

Paved roads are defaults, not walls. If a service needs something the chart cannot express (a sidecar, a StatefulSet, a public endpoint), use the chart's values first, then open an issue on this repo. If the need is real for more than one team, it becomes a chart feature; if it is unique, the team owns its own manifests and keeps the rest of the path (CI, image, AWS baseline).
