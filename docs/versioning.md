# Versioning and upgrades

Consumers never point at `main`. Each piece is pinned to a release:

| Piece | Consumers pin | Example |
|---|---|---|
| Reusable workflows | a major tag | `reusable-go.yml@v1` |
| GitLab components | an exact version | `go@1.0.0` |
| Helm chart | an exact chart version | `--version 0.1.0` |
| Terraform module | a tag in the module source | `?ref=v1.2.0` |

## Rules

- **Patch and minor releases** must not break a consumer: new inputs get defaults, outputs are only added, the chart's defaults only get safer when the change is safe for every existing value set.
- **Major releases** may break, and ship with an upgrade note in the release description: what changed, why, and the exact edit consumers make.
- The `v1` tag moves forward with each `1.x` release, so workflow consumers get fixes without editing anything. Everything else updates through Dependabot or Renovate pull requests.

## Rolling out a change

1. Change the golden path; CI proves it on `hello-service` and on a freshly rendered skeleton.
2. Release it, and let one or two volunteer services take it first.
3. Watch their deploys and alerts for a few days, then announce it and let bots open the upgrade pull requests everywhere else.
