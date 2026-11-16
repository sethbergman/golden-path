# syntax=docker/dockerfile:1.7
#
# Golden-path image for Go services. Build from the service's directory:
#   docker build -f <golden-path>/docker/go/Dockerfile \
#     --build-arg MAIN=./cmd/<service> --build-arg VERSION=<git-sha> .
#
# - Static binary (CGO off), reproducible flags, version stamped in.
# - Distroless, non-root, no shell or package manager in the final image.
# - Module downloads cached across builds with a BuildKit cache mount.

ARG GO_VERSION=1.23

FROM golang:${GO_VERSION}-alpine AS build
WORKDIR /src
COPY go.mod go.sum* ./
RUN --mount=type=cache,target=/go/pkg/mod go mod download
COPY . .
ARG MAIN=./cmd/app
ARG VERSION=dev
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 go build -trimpath -buildvcs=false \
      -ldflags="-s -w -X main.version=${VERSION}" -o /out/app "${MAIN}"

FROM gcr.io/distroless/static-debian12:nonroot
#checkov:skip=CKV_DOCKER_2:Health is checked by Kubernetes probes on /healthz and /readyz; distroless has no shell
COPY --from=build /out/app /app
USER 65532:65532
EXPOSE 8080
ENTRYPOINT ["/app"]
