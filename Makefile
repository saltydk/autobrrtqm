.DEFAULT_GOAL  := build
CMD            = tqm
GOARCH         = $(shell go env GOARCH)
GOOS           = $(shell go env GOOS)
TARGET         = ${GOOS}_${GOARCH}
DIST_PATH      = dist
BUILD_PATH     = ${DIST_PATH}/${CMD}_${TARGET}
DESTDIR        = /usr/local/bin
GO_FILES       = $(shell find . -path ./vendor -prune -or -type f -name '*.go' -print)
GO_PACKAGES    = $(shell go list -mod vendor ./...)
GIT_COMMIT     = $(shell git rev-parse --short HEAD)
TIMESTAMP      = $(shell date +%s)
VERSION        ?= 0.0.0-dev

# Deps
.PHONY: check_goreleaser
check_goreleaser:
	@command -v goreleaser >/dev/null || (echo "goreleaser is required."; exit 1)

.PHONY: test
test: ## Run tests
	@echo "*** go test ***"
	go test -cover -v -race ${GO_PACKAGES}

.PHONY: vendor
vendor: ## Vendor files and tidy go.mod
	go mod vendor
	go mod tidy

.PHONY: vendor_update
vendor_update: ## Update vendor dependencies
	go get -u ./...
	${MAKE} vendor

.PHONY: build
build: fetch ${BUILD_PATH}/${CMD} ## Build application

# Binary
${BUILD_PATH}/${CMD}: ${GO_FILES} go.sum
	@echo "Building for ${TARGET}..." && \
	mkdir -p ${BUILD_PATH} && \
	CGO_ENABLED=0 go build \
		-mod vendor \
		-trimpath \
		-ldflags "-s -w -X github.com/autobrr/tqm/runtime.Version=${VERSION} -X github.com/autobrr/tqm/runtime.GitCommit=${GIT_COMMIT} -X github.com/autobrr/tqm/runtime.Timestamp=${TIMESTAMP}" \
		-o ${BUILD_PATH}/${CMD} \
		./cmd/tqm

.PHONY: install
install: build ## Install binary
	install -m 0755 ${BUILD_PATH}/${CMD} ${DESTDIR}/${CMD}

.PHONY: clean
clean: ## Cleanup
	rm -rf ${DIST_PATH}

.PHONY: fetch
fetch: ## Fetch vendor files
	go mod vendor

.PHONY: release
release: check_goreleaser ## Generate a release, but don't publish
	goreleaser --skip=validate --skip=publish --clean

.PHONY: publish
publish: check_goreleaser ## Generate a release, and publish
	goreleaser --clean

.PHONY: snapshot
snapshot: check_goreleaser ## Generate a snapshot release
	goreleaser --snapshot --skip=publish --clean

.PHONY: help
help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
