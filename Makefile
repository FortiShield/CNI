.PHONY: build test run clean help build-all build-chunks build-base build-containers security-scan lint size shell

# Default target
all: build-all

# Load version variables from unified dependency management
include versions.env
export

# Global Variables
REGISTRY ?= $(DEFAULT_REGISTRY)
IMAGE_TAG ?= latest
PARALLEL ?= $(PARALLEL_BUILDS)
BUILD_PLATFORMS ?= linux/amd64,linux/arm64

# Language chunks
LANG_CHUNKS = lang-go lang-node lang-python lang-rust lang-php lang-java lang-ruby lang-cpp lang-csharp lang-elixir
BASE_COMPONENTS = alpine-certificates base git-base cfssl-self-sign container-registry kubectl postgresql

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[0;33m
BLUE := \033[0;34m
NC := \033[0m # No Color

# Function to print colored output
define print_status
	@echo "$(GREEN)[$(shell date +%H:%M:%S)]$(NC) $(BLUE)$(1)$(NC)"
endef

define print_warning
	@echo "$(YELLOW)[$(shell date +%H:%M:%S)] WARNING:$(NC) $(1)"
endef

define print_error
	@echo "$(RED)[$(shell date +%H:%M:%S)] ERROR:$(NC) $(1)"
endef

# =============================================================================
# BuildKit and Performance Optimization
# =============================================================================

# Setup BuildKit for optimized builds
setup-buildkit:
	$(call print_status,"Setting up BuildKit for optimized builds...")
	@cd build-scripts && ./setup-buildkit.sh

# Build with BuildKit optimization
build-optimized: setup-buildkit
	$(call print_status,"Building all components with BuildKit optimization...")
	@export DOCKER_BUILDKIT=1 BUILDKIT_INLINE_CACHE=1 && \
	$(MAKE) build-all-optimized

# Build all components with optimization
build-all-optimized: build-base-optimized build-chunks-optimized build-containers-optimized
	$(call print_status,"All optimized components built successfully!")

# Build base components with optimization
build-base-optimized:
	$(call print_status,"Building base components with optimization...")
	@for component in $(BASE_COMPONENTS); do \
		echo "Building $$component with optimization..."; \
		docker buildx build \
			--platform $(BUILD_PLATFORMS) \
			--cache-from type=gha,scope=$$component \
			--cache-to type=gha,mode=max,scope=$$component \
			--build-arg BASE_DEBIAN_VERSION=$(BASE_DEBIAN_VERSION) \
			--build-arg BASE_USER_UID=$(BASE_USER_UID) \
			--build-arg BASE_USER_GID=$(BASE_USER_GID) \
			--build-arg BASE_USERNAME=$(BASE_USERNAME) \
			-t $(REGISTRY)/$(IMAGE_NAMESPACE)/$$component:$(IMAGE_TAG) \
			-f $$component/Dockerfile \
			.$$component || { $(call print_error,"Failed to build $$component"); exit 1; }; \
	done
	$(call print_status,"Optimized base components built successfully!")

# Build language chunks with optimization
build-chunks-optimized:
	$(call print_status,"Building language chunks with optimization...")
	@for chunk in $(LANG_CHUNKS); do \
		echo "Building $$chunk with optimization..."; \
		docker buildx build \
			--platform $(BUILD_PLATFORMS) \
			--cache-from type=gha,scope=$$chunk \
			--cache-to type=gha,mode=max,scope=$$chunk \
			--build-arg BASE_DEBIAN_VERSION=$(BASE_DEBIAN_VERSION) \
			--build-arg PYTHON_VERSION=$(PYTHON_VERSION) \
			--build-arg GO_VERSION=$(GO_VERSION) \
			--build-arg NODE_VERSION=$(NODE_VERSION) \
			--build-arg BASE_USER_UID=$(BASE_USER_UID) \
			--build-arg BASE_USER_GID=$(BASE_USER_GID) \
			--build-arg BASE_USERNAME=$(BASE_USERNAME) \
			-t $(REGISTRY)/$(IMAGE_NAMESPACE)/$$chunk:$(IMAGE_TAG) \
			-f chunks/$$chunk/Dockerfile \
			.chunks/$$chunk || { $(call print_error,"Failed to build $$chunk"); exit 1; }; \
	done
	$(call print_status,"Optimized language chunks built successfully!")

# Build container registry components with optimization
build-containers-optimized:
	$(call print_status,"Building container registry components with optimization...")
	@docker buildx build \
		--platform $(BUILD_PLATFORMS) \
		--cache-from type=gha,scope=container-registry \
		--cache-to type=gha,mode=max,scope=container-registry \
		--build-arg BASE_DEBIAN_VERSION=$(BASE_DEBIAN_VERSION) \
		--build-arg BASE_USER_UID=$(BASE_USER_UID) \
		--build-arg BASE_USER_GID=$(BASE_USER_GID) \
		--build-arg BASE_USERNAME=$(BASE_USERNAME) \
		-t $(REGISTRY)/$(IMAGE_NAMESPACE)/container-registry:$(IMAGE_TAG) \
		-f container-registry/Dockerfile \
		.container-registry
	$(call print_status,"Optimized container registry components built successfully!")

# =============================================================================
# Main Build Targets
# =============================================================================

# Build all components
build-all: build-base build-chunks build-containers
	$(call print_status,"All components built successfully!")

# Build base components
build-base:
	$(call print_status,"Building base components...")
	@for component in $(BASE_COMPONENTS); do \
		echo "Building $$component..."; \
		$(MAKE) -C $$component build || { $(call print_error,"Failed to build $$component"); exit 1; }; \
	done
	$(call print_status,"Base components built successfully!")

# Build language chunks
build-chunks:
	$(call print_status,"Building language chunks...")
	@for chunk in $(LANG_CHUNKS); do \
		echo "Building $$chunk..."; \
		$(MAKE) -C chunks/$$chunk build || { $(call print_error,"Failed to build $$chunk"); exit 1; }; \
	done
	$(call print_status,"Language chunks built successfully!")

# Build container registry components
build-containers:
	$(call print_status,"Building container registry components...")
	@$(MAKE) -C container-registry build
	$(call print_status,"Container registry components built successfully!")

# =============================================================================
# Individual Component Builds
# =============================================================================

# Build specific language chunk
build-chunk:
	@if [ -z "$(CHUNK)" ]; then \
		$(call print_error,"Usage: make build-chunk CHUNK=lang-go"); \
		exit 1; \
	fi
	$(call print_status,"Building language chunk: $(CHUNK)")
	@$(MAKE) -C chunks/$(CHUNK) build

# Build specific base component
build-component:
	@if [ -z "$(COMPONENT)" ]; then \
		$(call print_error,"Usage: make build-component COMPONENT=base"); \
		exit 1; \
	fi
	$(call print_status,"Building base component: $(COMPONENT)")
	@$(MAKE) -C $(COMPONENT) build

# =============================================================================
# Parallel Builds
# =============================================================================

# Build language chunks in parallel
build-chunks-parallel:
	$(call print_status,"Building language chunks in parallel (jobs: $(PARALLEL))...")
	@echo "$(LANG_CHUNKS)" | xargs -P $(PARALLEL) -I {} sh -c 'echo "Building {}..."; $(MAKE) -C chunks/{} build || exit 255'
	$(call print_status,"Parallel language chunk build completed!")

# Build base components in parallel
build-base-parallel:
	$(call print_status,"Building base components in parallel (jobs: $(PARALLEL))...")
	@echo "$(BASE_COMPONENTS)" | xargs -P $(PARALLEL) -I {} sh -c 'echo "Building {}..."; $(MAKE) -C {} build || exit 255'
	$(call print_status,"Parallel base component build completed!")

# =============================================================================
# Testing
# =============================================================================

# Unit tests for all components
test-unit:
	$(call print_status,"Running unit tests...")
	@export REGISTRY="$(REGISTRY)" && export IMAGE_NAMESPACE="$(IMAGE_NAMESPACE)" && \
	chmod +x tests/*.sh && \
	./tests/base_tests.sh && \
	./tests/language_tests.sh && \
	./tests/container_tests.sh
	$(call print_status,"Unit tests completed!")

# Unit tests for specific component
test-unit-component:
	@if [ -z "$(COMPONENT)" ]; then \
		$(call print_error,"Usage: make test-unit-component COMPONENT=base|language|container"); \
		exit 1; \
	fi
	$(call print_status,"Running unit tests for component: $(COMPONENT)")
	@export REGISTRY="$(REGISTRY)" && export IMAGE_NAMESPACE="$(IMAGE_NAMESPACE)" && \
	chmod +x tests/*.sh && \
	case "$(COMPONENT)" in \
		base) ./tests/base_tests.sh ;; \
		language) ./tests/language_tests.sh ;; \
		container) ./tests/container_tests.sh ;; \
		*) $(call print_error,"Unknown component: $(COMPONENT)"); exit 1 ;; \
	esac

# Integration tests
test-integration:
	$(call print_status,"Running integration tests...")
	@export REGISTRY="$(REGISTRY)" && export IMAGE_NAMESPACE="$(IMAGE_NAMESPACE)" && \
	chmod +x tests/*.sh && \
	./tests/integration_tests.sh
	$(call print_status,"Integration tests completed!")

# All tests (unit + integration)
test-all-new:
	$(call print_status,"Running all tests...")
	@$(MAKE) test-unit
	@$(MAKE) test-integration
	$(call print_status,"All tests completed!")

# Generate test coverage report
test-coverage:
	$(call print_status,"Generating test coverage report...")
	@export REPORT_DIR="/tmp/test-results" && export COVERAGE_DIR="/tmp/test-results/coverage" && \
	chmod +x tests/*.sh && \
	./tests/coverage_report.sh
	$(call print_status,"Coverage report generated!")

# Test with coverage
test-with-coverage:
	$(call print_status,"Running tests with coverage...")
	@$(MAKE) test-all-new
	@$(MAKE) test-coverage
	$(call print_status,"Tests with coverage completed!")

# Quick test (basic functionality only)
test-quick:
	$(call print_status,"Running quick tests...")
	@for component in $(BASE_COMPONENTS); do \
		echo "Quick testing $$component..."; \
		$(MAKE) -C $$component test-quick || { $(call print_error,"Quick test failed for $$component"); exit 1; }; \
	done
	@for chunk in $(LANG_CHUNKS); do \
		echo "Quick testing $$chunk..."; \
		$(MAKE) -C chunks/$$chunk test-quick || { $(call print_error,"Quick test failed for $$chunk"); exit 1; }; \
	done
	$(call print_status,"Quick tests completed!")

# Test all components (legacy compatibility)
test-all:
	$(call print_status,"Testing all components...")
	@for component in $(BASE_COMPONENTS); do \
		echo "Testing $$component..."; \
		$(MAKE) -C $$component test || { $(call print_error,"Failed to test $$component"); exit 1; }; \
	done
	@for chunk in $(LANG_CHUNKS); do \
		echo "Testing $$chunk..."; \
		$(MAKE) -C chunks/$$chunk test || { $(call print_error,"Failed to test $$chunk"); exit 1; }; \
	done
	$(call print_status,"All tests passed!")

# Test specific component
test-component:
	@if [ -z "$(COMPONENT)" ]; then \
		$(call print_error,"Usage: make test-component COMPONENT=base"); \
		exit 1; \
	fi
	$(call print_status,"Testing component: $(COMPONENT)")
	@$(MAKE) -C $(COMPONENT) test

# =============================================================================
# Development and Debugging
# =============================================================================

# Run development environment
dev:
	$(call print_status,"Starting development environment...")
	@docker-compose -f docker-compose.yml up -d
	$(call print_status,"Development environment started!")

# Stop development environment
dev-stop:
	$(call print_status,"Stopping development environment...")
	@docker-compose -f docker-compose.yml down
	$(call print_status,"Development environment stopped!")

# Show logs for development environment
logs:
	@docker-compose -f docker-compose.yml logs -f

# =============================================================================
# Security and Quality
# =============================================================================

# Security scan all images
security-scan-all:
	$(call print_status,"Running security scans on all images...")
	@for component in $(BASE_COMPONENTS); do \
		echo "Scanning $$component..."; \
		$(MAKE) -C $$component security-scan || $(call print_warning,"Security scan failed for $$component"); \
	done
	@for chunk in $(LANG_CHUNKS); do \
		echo "Scanning $$chunk..."; \
		$(MAKE) -C chunks/$$chunk security-scan || $(call print_warning,"Security scan failed for $$chunk"); \
	done
	$(call print_status,"Security scans completed!")

# Lint all Dockerfiles
lint-all:
	$(call print_status,"Linting all Dockerfiles...")
	@find . -name "Dockerfile*" -type f -exec echo "Linting {}..." \; -exec docker run --rm -v $(PWD):/.cache/ hadolint/hadolint hadolint {} \;
	$(call print_status,"Linting completed!")

# Check image sizes
size-all:
	$(call print_status,"Showing image sizes...")
	@echo "=== Base Components ==="
	@for component in $(BASE_COMPONENTS); do \
		echo "$$component:"; \
		docker images | grep $$component || echo "  Not found"; \
	done
	@echo "=== Language Chunks ==="
	@for chunk in $(LANG_CHUNKS); do \
		echo "$$chunk:"; \
		docker images | grep $$chunk || echo "  Not found"; \
	done

# =============================================================================
# Cleanup
# =============================================================================

# Clean all built images
clean-all:
	$(call print_status,"Cleaning all built images...")
	@for component in $(BASE_COMPONENTS); do \
		$(MAKE) -C $$component clean || true; \
	done
	@for chunk in $(LANG_CHUNKS); do \
		$(MAKE) -C chunks/$$chunk clean || true; \
	done
	@docker system prune -f
	$(call print_status,"Cleanup completed!")

# Clean specific component
clean-component:
	@if [ -z "$(COMPONENT)" ]; then \
		$(call print_error,"Usage: make clean-component COMPONENT=base"); \
		exit 1; \
	fi
	$(call print_status,"Cleaning component: $(COMPONENT)")
	@$(MAKE) -C $(COMPONENT) clean

# =============================================================================
# Utilities
# =============================================================================

# List all available components
list-components:
	@echo "=== Base Components ==="
	@for component in $(BASE_COMPONENTS); do echo "  $$component"; done
	@echo ""
	@echo "=== Language Chunks ==="
	@for chunk in $(LANG_CHUNKS); do echo "  $$chunk"; done

# Check prerequisites
check-prereqs:
	$(call print_status,"Checking prerequisites...")
	@command -v docker >/dev/null 2>&1 || { $(call print_error,"Docker is not installed"); exit 1; }
	@command -v docker-compose >/dev/null 2>&1 || { $(call print_error,"Docker Compose is not installed"); exit 1; }
	@docker info >/dev/null 2>&1 || { $(call print_error,"Docker daemon is not running"); exit 1; }
	$(call print_status,"Prerequisites check passed!")

# Show build status
status:
	$(call print_status,"Build status:")
	@echo "=== Base Components ==="
	@for component in $(BASE_COMPONENTS); do \
		if docker images | grep -q $$component; then \
			echo "  ✓ $$component"; \
		else \
			echo "  ✗ $$component (not built)"; \
		fi; \
	done
	@echo "=== Language Chunks ==="
	@for chunk in $(LANG_CHUNKS); do \
		if docker images | grep -q $$chunk; then \
			echo "  ✓ $$chunk"; \
		else \
			echo "  ✗ $$chunk (not built)"; \
		fi; \
	done

# =============================================================================
# Help
# =============================================================================

help:
	@echo "CNI Container Build System"
	@echo "========================="
	@echo ""
	@echo "Main Targets:"
	@echo "  all                  - Build all components (default)"
	@echo "  build-all            - Build all components"
	@echo "  build-base           - Build base components"
	@echo "  build-chunks         - Build language chunks"
	@echo "  build-containers     - Build container registry components"
	@echo ""
	@echo "Individual Builds:"
	@echo "  build-chunk CHUNK=lang-go    - Build specific language chunk"
	@echo "  build-component COMPONENT=base - Build specific base component"
	@echo ""
	@echo "Parallel Builds:"
	@echo "  build-chunks-parallel - Build language chunks in parallel"
	@echo "  build-base-parallel   - Build base components in parallel"
	@echo ""
	@echo "Testing:"
	@echo "  test-unit             - Run unit tests for all components"
	@echo "  test-unit-component COMPONENT=base - Run unit tests for specific component"
	@echo "  test-integration      - Run integration tests"
	@echo "  test-all-new          - Run all tests (unit + integration)"
	@echo "  test-coverage         - Generate test coverage report"
	@echo "  test-with-coverage    - Run tests with coverage reporting"
	@echo "  test-quick            - Run quick basic functionality tests"
	@echo "  test-all              - Legacy test all components (basic checks)"
	@echo ""
	@echo "Development:"
	@echo "  dev                  - Start development environment"
	@echo "  dev-stop             - Stop development environment"
	@echo "  logs                 - Show development logs"
	@echo ""
	@echo "Security & Quality:"
	@echo "  security-scan-all    - Security scan all images"
	@echo "  lint-all             - Lint all Dockerfiles"
	@echo "  size-all             - Show image sizes"
	@echo ""
	@echo "Cleanup:"
	@echo "  clean-all            - Clean all built images"
	@echo "  clean-component COMPONENT=base - Clean specific component"
	@echo ""
	@echo "Utilities:"
	@echo "  list-components      - List all available components"
	@echo "  check-prereqs        - Check prerequisites"
	@echo "  status               - Show build status"
	@echo "  help                 - Show this help"
	@echo ""
	@echo "Variables:"
	@echo "  REGISTRY             - Docker registry (default: cni)"
	@echo "  IMAGE_TAG            - Docker image tag (default: latest)"
	@echo "  ALPINE_VERSION       - Alpine Linux version (default: 3.19)"
	@echo "  PARALLEL             - Parallel build jobs (default: 4)"
	@echo ""
	@echo "Examples:"
	@echo "  make build-chunk CHUNK=lang-go"
	@echo "  make build-chunks-parallel PARALLEL=8"
	@echo "  make test-unit-component COMPONENT=base"
	@echo "  make test-with-coverage"
	@echo "  make security-scan-all"
