# Makefile for Git base container
# Provides build, test, and development targets

# Default target
.PHONY: default
default: build

# Variables
IMAGE_NAME := git-base
GIT_VERSION := 2.43.0
UBI_VERSION := 8.8
REGISTRY ?= your-registry.com
TAG ?= latest

# Build targets
.PHONY: build build-debian build-ubi8 build-ubi8-multi
build: build-debian

build-debian:
	@echo "Building Git container with Debian base..."
	docker build -t $(IMAGE_NAME):$(TAG) \
		--build-arg GIT_VERSION=$(GIT_VERSION) \
		.

build-ubi8:
	@echo "Building Git container with UBI8 base..."
	docker build -f Dockerfile.ubi8 -t $(IMAGE_NAME):ubi8-$(TAG) \
		--build-arg GIT_VERSION=$(GIT_VERSION) \
		--build-arg UBI_IMAGE=registry.access.redhat.com/ubi8/ubi-minimal:$(UBI_VERSION) \
		.

build-ubi8-multi:
	@echo "Building Git container with UBI8 multi-stage..."
	docker build -f Dockerfile.build.ubi8 -t $(IMAGE_NAME):ubi8-build-$(TAG) \
		--build-arg GIT_VERSION=$(GIT_VERSION) \
		--build-arg UBI_IMAGE=registry.access.redhat.com/ubi8/ubi-minimal:$(UBI_VERSION) \
		.

# Test targets
.PHONY: test test-debian test-ubi8 test-all
test: test-debian

test-debian: build-debian
	@echo "Testing Debian Git container..."
	docker run --rm $(IMAGE_NAME):$(TAG) git --version
	docker run --rm $(IMAGE_NAME):$(TAG) ssh -V
	docker run --rm $(IMAGE_NAME):$(TAG) git config --list

test-ubi8: build-ubi8
	@echo "Testing UBI8 Git container..."
	docker run --rm $(IMAGE_NAME):ubi8-$(TAG) git --version
	docker run --rm $(IMAGE_NAME):ubi8-$(TAG) ssh -V
	docker run --rm $(IMAGE_NAME):ubi8-$(TAG) git config --list

test-all: test-debian test-ubi8
	@echo "All tests completed successfully!"

# Development targets
.PHONY: dev dev-shell dev-test
dev: build-debian
	@echo "Starting development container..."
	docker run -it --rm \
		-e GIT_USER_NAME="Dev User" \
		-e GIT_USER_EMAIL="dev@example.com" \
		-v $(PWD):/workspace \
		-w /workspace \
		$(IMAGE_NAME):$(TAG)

dev-shell: build-debian
	@echo "Starting interactive shell..."
	docker run -it --rm \
		-e GIT_USER_NAME="Dev User" \
		-e GIT_USER_EMAIL="dev@example.com" \
		-v $(PWD):/workspace \
		-w /workspace \
		$(IMAGE_NAME):$(TAG) /bin/bash

dev-test: build-debian
	@echo "Running setup script in development mode..."
	docker run --rm \
		-e GIT_USER_NAME="Test User" \
		-e GIT_USER_EMAIL="test@example.com" \
		-v $(PWD):/workspace \
		-w /workspace \
		$(IMAGE_NAME):$(TAG) /scripts/setup-git.sh

# Health check targets
.PHONY: health health-debian health-ubi8
health: health-debian

health-debian: build-debian
	@echo "Checking health of Debian container..."
	docker run --rm --health-interval=5s $(IMAGE_NAME):$(TAG)
	@echo "Health check passed!"

health-ubi8: build-ubi8
	@echo "Checking health of UBI8 container..."
	docker run --rm --health-interval=5s $(IMAGE_NAME):ubi8-$(TAG)
	@echo "Health check passed!"

# Security targets
.PHONY: security security-scan security-scan-all
security: security-scan

security-scan:
	@echo "Running security scan on Debian image..."
	docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
		aquasec/trivy:latest image $(IMAGE_NAME):$(TAG)

security-scan-ubi8: build-ubi8
	@echo "Running security scan on UBI8 image..."
	docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
		aquasec/trivy:latest image $(IMAGE_NAME):ubi8-$(TAG)

security-scan-all: security-scan security-scan-ubi8
	@echo "All security scans completed!"

# Lint targets
.PHONY: lint lint-dockerfile lint-shell
lint: lint-dockerfile lint-shell

lint-dockerfile:
	@echo "Linting Dockerfiles..."
	docker run --rm -v $(PWD):/work hadolint/hadolint:latest hadolint /work/Dockerfile
	docker run --rm -v $(PWD):/work hadolint/hadolint:latest hadolint /work/Dockerfile.ubi8
	docker run --rm -v $(PWD):/work hadolint/hadolint:latest hadolint /work/Dockerfile.build.ubi8

lint-shell:
	@echo "Linting shell scripts..."
	docker run --rm -v $(PWD):/work koalaman/shellcheck:latest shellcheck /work/scripts/*.sh

# Clean targets
.PHONY: clean clean-images clean-all
clean:
	@echo "Cleaning build artifacts..."
	rm -rf .git/objects/pack/*.pack .git/objects/pack/*.idx 2>/dev/null || true

clean-images:
	@echo "Removing built images..."
	docker rmi $(IMAGE_NAME):$(TAG) 2>/dev/null || true
	docker rmi $(IMAGE_NAME):ubi8-$(TAG) 2>/dev/null || true
	docker rmi $(IMAGE_NAME):ubi8-build-$(TAG) 2>/dev/null || true

clean-all: clean clean-images
	@echo "Complete cleanup finished!"

# Push targets
.PHONY: push push-all
push: build-debian
	@echo "Pushing Debian image to registry..."
	docker tag $(IMAGE_NAME):$(TAG) $(REGISTRY)/$(IMAGE_NAME):$(TAG)
	docker push $(REGISTRY)/$(IMAGE_NAME):$(TAG)

push-all: build-debian build-ubi8
	@echo "Pushing all images to registry..."
	docker tag $(IMAGE_NAME):$(TAG) $(REGISTRY)/$(IMAGE_NAME):$(TAG)
	docker push $(REGISTRY)/$(IMAGE_NAME):$(TAG)
	docker tag $(IMAGE_NAME):ubi8-$(TAG) $(REGISTRY)/$(IMAGE_NAME):ubi8-$(TAG)
	docker push $(REGISTRY)/$(IMAGE_NAME):ubi8-$(TAG)

# Multi-architecture build
.PHONY: build-multi
build-multi:
	@echo "Building multi-architecture images..."
	docker buildx build \
		--platform linux/amd64,linux/arm64 \
		--tag $(REGISTRY)/$(IMAGE_NAME):$(TAG) \
		--push \
		.

# Help target
.PHONY: help
help:
	@echo "Available targets:"
	@echo "  build          - Build Debian-based Git container"
	@echo "  build-ubi8     - Build UBI8-based Git container"
	@echo "  build-ubi8-multi - Build UBI8 multi-stage container"
	@echo "  test           - Test Debian container"
	@echo "  test-ubi8      - Test UBI8 container"
	@echo "  test-all       - Test all containers"
	@echo "  dev            - Start development container"
	@echo "  dev-shell      - Start interactive shell"
	@echo "  dev-test       - Run setup script in development"
	@echo "  health         - Check health of Debian container"
	@echo "  health-ubi8    - Check health of UBI8 container"
	@echo "  security       - Run security scan on Debian image"
	@echo "  security-scan-ubi8 - Run security scan on UBI8 image"
	@echo "  lint           - Lint Dockerfiles and shell scripts"
	@echo "  clean          - Clean build artifacts"
	@echo "  clean-images   - Remove built images"
	@echo "  clean-all      - Complete cleanup"
	@echo "  push           - Push Debian image to registry"
	@echo "  push-all       - Push all images to registry"
	@echo "  build-multi    - Build multi-architecture images"
	@echo "  help           - Show this help message"
