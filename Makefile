.PHONY: help test skeleton image chart fmt

help: ## Show targets
	@grep -E '^[a-z-]+:.*##' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-10s %s\n", $$1, $$2}'

test: ## Vet and test the example service
	cd examples/hello-service && go vet ./... && go test -race ./...

skeleton: ## Render the Backstage template and test the generated service
	rm -rf .skeleton-out && python3 scripts/render-skeleton.py .skeleton-out >/dev/null
	cd .skeleton-out && go vet ./... && go test -race ./... && go build -o /dev/null ./cmd/orders-api
	@echo "generated service OK (.skeleton-out)"

image: ## Build hello-service with the golden-path Dockerfile
	docker build -f docker/go/Dockerfile --build-arg MAIN=./cmd/hello-service \
		-t hello-service:dev examples/hello-service

chart: ## Lint and render the chart with the example's values
	helm lint charts/service -f examples/hello-service/deploy/values.yaml --strict
	helm template hello-service charts/service -f examples/hello-service/deploy/values.yaml

fmt: ## Format Go and Terraform
	gofmt -w examples backstage/skeleton/internal
	terraform fmt -recursive terraform
