.DEFAULT_GOAL := help
.PHONY: run run-help test test-core test-libc test-lint build-libc check cover
.PHONY: integration-test-stable integration-test-live integration-test-live-wallet
.PHONY: integration-test-disable-wallet-api integration-test-disable-seed-api
.PHONY: install-linters format release clean-release install-deps-ui build-ui help

# Static files directory
GUI_STATIC_DIR = src/gui/static

# Electron files directory
ELECTRON_DIR = electron

# ./src folder does not have code
# ./src/api folder does not have code
# ./src/util folder does not have code
# ./src/ciper/* are libraries manually vendored by cipher that do not need coverage
# ./src/gui/static* are static assets
# */testdata* folders do not have code
# ./src/consensus/example has no buildable code
PACKAGES = $(shell find ./src -type d -not -path '\./src' \
    							      -not -path '\./src/api' \
    							      -not -path '\./src/util' \
    							      -not -path '\./src/consensus/example' \
    							      -not -path '\./src/gui/static*' \
    							      -not -path '\./src/cipher/*' \
    							      -not -path '*/testdata*' \
    							      -not -path '*/test-fixtures*')

# Compilation output
BUILD_DIR = build
BUILDLIB_DIR = $(BUILD_DIR)/libdollarydoos
LIB_DIR = lib
LIB_FILES = $(shell find ./lib/cgo -type f -name "*.go")
BIN_DIR = bin
INCLUDE_DIR = include

# Compilation flags
CC = gcc
LIBC_LIBS = -lcriterion
LDFLAGS = -I$(INCLUDE_DIR) -I$(BUILD_DIR)/usr/include -L $(BUILDLIB_DIR) -L$(BUILD_DIR)/usr/lib

# Platform specific checks
OSNAME = $(TRAVIS_OS_NAME)

ifeq ($(shell uname -s),Linux)
  LDLIBS=$(LIBC_LIBS) -lpthread
	LDPATH=$(shell printenv LD_LIBRARY_PATH)
	LDPATHVAR=LD_LIBRARY_PATH
ifndef OSNAME
  OSNAME = linux
endif
else ifeq ($(shell uname -s),Darwin)
ifndef OSNAME
  OSNAME = osx
endif
	LDLIBS = $(LIBC_LIBS)
	LDPATH=$(shell printenv DYLD_LIBRARY_PATH)
	LDPATHVAR=DYLD_LIBRARY_PATH
else
	LDLIBS = $(LIBC_LIBS)
	LDPATH=$(shell printenv LD_LIBRARY_PATH)
	LDPATHVAR=LD_LIBRARY_PATH
endif

run:  ## Run the dollarydoos node. To add arguments, do 'make ARGS="--foo" run'.
	./run.sh ${ARGS}

run-help: ## Show dollarydoos node help
	@go run cmd/dollarydoos/dollarydoos.go --help

test: ## Run tests for dollarydoos
	go test ./cmd/... -timeout=5m
	go test ./src/... -timeout=5m

test-386: ## Run tests for dollarydoos with GOARCH=386
	GOARCH=386 go test ./cmd/... -timeout=5m
	GOARCH=386 go test ./src/... -timeout=5m

test-amd64: ## Run tests for dollarydoos with GOARCH=amd64
	GOARCH=amd64 go test ./cmd/... -timeout=5m
	GOARCH=amd64 go test ./src/... -timeout=5m

configure-build:
	mkdir -p $(BUILD_DIR)/usr/tmp $(BUILD_DIR)/usr/lib $(BUILD_DIR)/usr/include
	mkdir -p $(BUILDLIB_DIR) $(BIN_DIR) $(INCLUDE_DIR)

build-libc: configure-build ## Build libdollarydoos C client library
	rm -Rf $(BUILDLIB_DIR)/*
	go build -buildmode=c-shared  -o $(BUILDLIB_DIR)/libdollarydoos.so $(LIB_FILES)
	go build -buildmode=c-archive -o $(BUILDLIB_DIR)/libdollarydoos.a  $(LIB_FILES)
	mv $(BUILDLIB_DIR)/libdollarydoos.h $(INCLUDE_DIR)/

test-libc: build-libc ## Run tests for libdollarydoos C client library
	cp $(LIB_DIR)/cgo/tests/*.c $(BUILDLIB_DIR)/
	$(CC) -o $(BIN_DIR)/test_libdollarydoos_shared $(BUILDLIB_DIR)/*.c -ldollarydoos                    $(LDLIBS) $(LDFLAGS)
	$(CC) -o $(BIN_DIR)/test_libdollarydoos_static $(BUILDLIB_DIR)/*.c $(BUILDLIB_DIR)/libdollarydoos.a $(LDLIBS) $(LDFLAGS)
	$(LDPATHVAR)="$(LDPATH):$(BUILD_DIR)/usr/lib"                 $(BIN_DIR)/test_libdollarydoos_static
	$(LDPATHVAR)="$(LDPATH):$(BUILD_DIR)/usr/lib:$(BUILDLIB_DIR)" $(BIN_DIR)/test_libdollarydoos_shared

lint: ## Run linters. Use make install-linters first.
	vendorcheck ./...
	gometalinter --deadline=3m --concurrency=2 --disable-all --tests --vendor --skip=lib/cgo \
		-E goimports \
		-E golint \
		-E varcheck \
		./...
	# lib cgo can't use golint because it needs export directives in function docstrings that do not obey golint rules
	gometalinter --deadline=3m --concurrency=2 --disable-all --tests --vendor --skip=lib/cgo \
		-E goimports \
		-E varcheck \
		./...

check: lint test integration-test-stable integration-test-disable-wallet-api integration-test-disable-seed-api ## Run tests and linters

integration-test-stable: ## Run stable integration tests
	./ci-scripts/integration-test-stable.sh

integration-test-live: ## Run live integration tests
	./ci-scripts/integration-test-live.sh

integration-test-live-wallet: ## Run live integration tests with wallet
	./ci-scripts/integration-test-live.sh -w

integration-test-disable-wallet-api: ## Run disable wallet api integration tests
	./ci-scripts/integration-test-disable-wallet-api.sh

integration-test-disable-seed-api: ## Run enable seed api integration test
	./ci-scripts/integration-test-disable-seed-api.sh

cover: ## Runs tests on ./src/ with HTML code coverage
	go test -cover -coverprofile=cover.out -coverpkg=github.com/dollarydooslab/dollarydoos/... ./src/...
	go tool cover -html=cover.out

install-linters: ## Install linters
	go get -u github.com/FiloSottile/vendorcheck
	go get -u github.com/alecthomas/gometalinter
	gometalinter --vendored-linters --install

install-deps-libc: configure-build ## Install locally dependencies for testing libdollarydoos
	wget -O $(BUILD_DIR)/usr/tmp/criterion-v2.3.2-$(OSNAME)-x86_64.tar.bz2 https://github.com/Snaipe/Criterion/releases/download/v2.3.2/criterion-v2.3.2-$(OSNAME)-x86_64.tar.bz2
	tar -x -C $(BUILD_DIR)/usr/tmp/ -j -f $(BUILD_DIR)/usr/tmp/criterion-v2.3.2-$(OSNAME)-x86_64.tar.bz2
	ls $(BUILD_DIR)/usr/tmp/criterion-v2.3.2/include
	ls -1 $(BUILD_DIR)/usr/tmp/criterion-v2.3.2/lib     | xargs -I NAME mv $(BUILD_DIR)/usr/tmp/criterion-v2.3.2/lib/NAME     $(BUILD_DIR)/usr/lib/NAME
	ls -1 $(BUILD_DIR)/usr/tmp/criterion-v2.3.2/include | xargs -I NAME mv $(BUILD_DIR)/usr/tmp/criterion-v2.3.2/include/NAME $(BUILD_DIR)/usr/include/NAME

format: ## Formats the code. Must have goimports installed (use make install-linters).
	goimports -w -local github.com/dollarydooslab/dollarydoos ./cmd
	goimports -w -local github.com/dollarydooslab/dollarydoos ./src
	goimports -w -local github.com/dollarydooslab/dollarydoos ./lib

install-deps-ui:  ## Install the UI dependencies
	cd $(GUI_STATIC_DIR) && npm install

lint-ui:  ## Lint the UI code
	cd $(GUI_STATIC_DIR) && npm run lint

test-ui:  ## Run UI tests
	cd $(GUI_STATIC_DIR) && npm run test
	cd $(GUI_STATIC_DIR) && npm run e2e

build-ui:  ## Builds the UI
	cd $(GUI_STATIC_DIR) && npm run build

release: ## Build electron apps, the builds are located in electron/release folder.
	cd $(ELECTRON_DIR) && ./build.sh
	@echo release files are in the folder of electron/release

clean-release: ## Clean dist files and delete all builds in electron/release
	rm $(ELECTRON_DIR)/release/*

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'