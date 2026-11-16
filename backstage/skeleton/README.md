# ${{ values.name }}

${{ values.description }}

Owned by `${{ values.owner }}`. Created from the golden path, so it already has:

- a Go HTTP service with `/healthz`, `/readyz` and `/metrics`, graceful shutdown and JSON logs;
- a distroless, non-root image built with an SBOM and provenance, and scanned in CI;
- CI on GitHub Actions (`.github/workflows/ci.yml`) and on GitLab (`.gitlab-ci.yml`);
- deployment values for the golden-path Helm chart (`deploy/values.yaml`).

## Develop

```bash
go test ./...
go run ./cmd/${{ values.name }}   # then: curl localhost:8080/hello?name=you
```

## Deploy

Merges to `main` build and push an image. Deploys pin the image by digest, so
production runs exactly what CI tested.
