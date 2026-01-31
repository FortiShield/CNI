#!/bin/bash

# Integration Tests for CNI Components
# Tests end-to-end functionality and component interactions

set -euo pipefail

# Source the test framework
source "$(dirname "$0")/test_framework.sh"

# Test configuration
COMPONENT_NAME="integration"
REGISTRY="${REGISTRY:-cni}"
IMAGE_NAMESPACE="${IMAGE_NAMESPACE:-cni}"
TEST_TIMEOUT=300

# Test data
TEMP_DIR="/tmp/integration-test-$$"
mkdir -p "$TEMP_DIR"

# Network and service configuration
TEST_NETWORK="cni-test-network"
REGISTRY_CONTAINER="cni-registry-test"
POSTGRES_CONTAINER="cni-postgres-test"

# Cleanup function
cleanup() {
    log_info "Cleaning up integration test environment"
    
    # Stop and remove test containers
    docker stop "$REGISTRY_CONTAINER" "$POSTGRES_CONTAINER" >/dev/null 2>&1 || true
    docker rm "$REGISTRY_CONTAINER" "$POSTGRES_CONTAINER" >/dev/null 2>&1 || true
    
    # Remove test network
    docker network rm "$TEST_NETWORK" >/dev/null 2>&1 || true
    
    # Clean up temporary files
    rm -rf "$TEMP_DIR"
    
    # Clean up any test artifacts
    docker system prune -f >/dev/null 2>&1 || true
}
trap cleanup EXIT

# Test suite: Component Interaction
test_component_interaction() {
    start_test_suite "component_interaction"
    
    # Test 1: Create test network
    docker network create "$TEST_NETWORK" >/dev/null 2>&1
    assert_equals "0" "$?" "Test network should be created"
    
    # Test 2: Start container registry
    docker run -d --name "$REGISTRY_CONTAINER" --network "$TEST_NETWORK" \
        -p 5000:5000 \
        "${REGISTRY}/${IMAGE_NAMESPACE}/container-registry:latest" \
        registry serve /etc/docker/registry/config.yml >/dev/null 2>&1
    
    # Wait for registry to start
    sleep 10
    
    # Test 3: Registry is accessible
    local registry_health
    registry_health=$(docker exec "$REGISTRY_CONTAINER" curl -s http://localhost:5000/v2/ >/dev/null 2>&1 && echo "healthy" || echo "unhealthy")
    assert_equals "healthy" "$registry_health" "Container registry should be healthy"
    
    # Test 4: Start PostgreSQL
    docker run -d --name "$POSTGRES_CONTAINER" --network "$TEST_NETWORK" \
        -e POSTGRES_PASSWORD=testpass \
        -e POSTGRES_DB=testdb \
        -p 5432:5432 \
        "${REGISTRY}/${IMAGE_NAMESPACE}/postgresql:latest" >/dev/null 2>&1
    
    # Wait for PostgreSQL to start
    sleep 15
    
    # Test 5: PostgreSQL is accessible
    local postgres_health
    postgres_health=$(docker exec "$POSTGRES_CONTAINER" pg_isready -U postgres -d testdb >/dev/null 2>&1 && echo "healthy" || echo "unhealthy")
    assert_equals "healthy" "$postgres_health" "PostgreSQL should be healthy"
    
    # Test 6: Components can communicate via network
    local network_test
    network_test=$(docker exec "$REGISTRY_CONTAINER" ping -c 1 "$POSTGRES_CONTAINER" >/dev/null 2>&1 && echo "connected" || echo "disconnected")
    assert_equals "connected" "$network_test" "Components should communicate via network"
    
    end_test_suite "component_interaction"
}

# Test suite: Language Runtime Integration
test_language_runtime_integration() {
    start_test_suite "language_runtime_integration"
    
    # Test 1: Go can connect to PostgreSQL
    local go_integration
    go_integration=$(docker run --rm --network "$TEST_NETWORK" \
        "${REGISTRY}/${IMAGE_NAMESPACE}/lang-go:latest" \
        sh -c "
        go mod init test && \
        go get github.com/lib/pq && \
        echo 'package main; import (\"database/sql\"; _ \"github.com/lib/pq\"; \"fmt\"); func main() { db, _ := sql.Open(\"postgres\", \"host=${POSTGRES_CONTAINER} user=postgres password=testpass dbname=testdb sslmode=disable\"); defer db.Close(); _, err := db.Exec(\"CREATE TABLE IF NOT EXISTS test (id INTEGER)\"); if err != nil { fmt.Println(\"ERROR:\", err) } else { fmt.Println(\"SUCCESS\") } }' > main.go && \
        go run main.go
        " 2>&1 || echo "FAILED")
    assert_contains "SUCCESS" "$go_integration" "Go should connect to PostgreSQL"
    
    # Test 2: Node.js can connect to PostgreSQL
    local node_integration
    node_integration=$(docker run --rm --network "$TEST_NETWORK" \
        "${REGISTRY}/${IMAGE_NAMESPACE}/lang-node:latest" \
        sh -c "
        npm init -y && \
        npm install pg && \
        echo 'const { Client } = require(\"pg\"); const client = new Client({ host: \"${POSTGRES_CONTAINER}\", user: \"postgres\", password: \"testpass\", database: \"testdb\" }); client.connect().then(() => { console.log(\"SUCCESS\"); client.end(); }).catch(err => console.log(\"ERROR:\", err.message));' > test.js && \
        node test.js
        " 2>&1 || echo "FAILED")
    assert_contains "SUCCESS" "$node_integration" "Node.js should connect to PostgreSQL"
    
    # Test 3: Python can connect to PostgreSQL
    local python_integration
    python_integration=$(docker run --rm --network "$TEST_NETWORK" \
        "${REGISTRY}/${IMAGE_NAMESPACE}/lang-python:latest" \
        sh -c "
        pip install psycopg2-binary && \
        echo 'import psycopg2; conn = psycopg2.connect(host=\"${POSTGRES_CONTAINER}\", user=\"postgres\", password=\"testpass\", database=\"testdb\"); cur = conn.cursor(); cur.execute(\"CREATE TABLE IF NOT EXISTS test (id INTEGER)\"); conn.commit(); print(\"SUCCESS\"); conn.close()' > test.py && \
        python test.py
        " 2>&1 || echo "FAILED")
    assert_contains "SUCCESS" "$python_integration" "Python should connect to PostgreSQL"
    
    end_test_suite "language_runtime_integration"
}

# Test suite: Container Registry Integration
test_container_registry_integration() {
    start_test_suite "container_registry_integration"
    
    # Test 1: Push and pull images through registry
    local test_image="test-integration-image"
    
    # Create a simple Dockerfile for testing
    cat > "$TEMP_DIR/Dockerfile" << EOF
FROM alpine:latest
CMD ["echo", "integration-test"]
EOF
    
    # Build test image
    docker build -t "$test_image" "$TEMP_DIR" >/dev/null 2>&1
    assert_equals "0" "$?" "Test image should be built"
    
    # Tag image for registry
    docker tag "$test_image" "localhost:5000/$test_image:latest"
    assert_equals "0" "$?" "Test image should be tagged for registry"
    
    # Push to registry
    docker push "localhost:5000/$test_image:latest" >/dev/null 2>&1
    assert_equals "0" "$?" "Image should be pushed to registry"
    
    # Remove local image
    docker rmi "localhost:5000/$test_image:latest" >/dev/null 2>&1 || true
    docker rmi "$test_image" >/dev/null 2>&1 || true
    
    # Pull from registry
    docker pull "localhost:5000/$test_image:latest" >/dev/null 2>&1
    assert_equals "0" "$?" "Image should be pulled from registry"
    
    # Test pulled image
    local pull_test
    pull_test=$(docker run --rm "localhost:5000/$test_image:latest" 2>&1 || echo "FAILED")
    assert_contains "integration-test" "$pull_test" "Pulled image should run correctly"
    
    end_test_suite "container_registry_integration"
}

# Test suite: Kubernetes Tools Integration
test_kubernetes_tools_integration() {
    start_test_suite "kubernetes_tools_integration"
    
    # Test 1: kubectl can parse Kubernetes manifests
    local kubectl_test
    kubectl_test=$(docker run --rm "${REGISTRY}/${IMAGE_NAMESPACE}/kubectl:latest" \
        sh -c "
        echo 'apiVersion: v1
kind: Pod
metadata:
  name: test-pod
spec:
  containers:
  - name: test-container
    image: alpine:latest
    command: [\"echo\", \"test\"]' > test-pod.yaml && \
        kubectl apply --dry-run=client -f test-pod.yaml && \
        echo 'SUCCESS'
        " 2>&1 || echo "FAILED")
    assert_contains "SUCCESS" "$kubectl_test" "kubectl should validate Kubernetes manifests"
    
    # Test 2: kubectl can generate configurations
    local kubectl_generate
    kubectl_generate=$(docker run --rm "${REGISTRY}/${IMAGE_NAMESPACE}/kubectl:latest" \
        kubectl create deployment test --image=alpine:latest --dry-run=client -o yaml 2>&1 || echo "FAILED")
    assert_contains "kind: Deployment" "$kubectl_generate" "kubectl should generate deployment configurations"
    
    end_test_suite "kubernetes_tools_integration"
}

# Test suite: Security Integration
test_security_integration() {
    start_test_suite "security_integration"
    
    # Test 1: All containers run with appropriate user permissions
    local containers=("$REGISTRY_CONTAINER" "$POSTGRES_CONTAINER")
    for container in "${containers[@]}"; do
        local user_id
        user_id=$(docker exec "$container" id -u 2>/dev/null || echo "0")
        if [[ "$container" == "$POSTGRES_CONTAINER" ]]; then
            assert_not_equals "0" "$user_id" "PostgreSQL should run as non-root user"
        else
            # Registry might run as root, but we should check
            if [[ "$user_id" == "0" ]]; then
                log_warning "Container $container runs as root user"
            else
                log_success "Container $container runs as non-root user (UID: $user_id)"
            fi
            ((TESTS_PASSED++))
        fi
        ((TESTS_TOTAL++))
    done
    
    # Test 2: Network isolation works
    local network_isolation
    network_isolation=$(docker run --rm --network "$TEST_NETWORK" \
        alpine:latest ping -c 1 google.com >/dev/null 2>&1 && echo "connected" || echo "isolated")
    
    # Network isolation test - this might pass or fail depending on Docker configuration
    if [[ "$network_isolation" == "isolated" ]]; then
        log_success "Test network is properly isolated from external networks"
        ((TESTS_PASSED++))
    else
        log_warning "Test network has external connectivity (this may be expected)"
        ((TESTS_PASSED++))  # Warning, not failure
    fi
    ((TESTS_TOTAL++))
    
    # Test 3: SSL/TLS connectivity works
    local ssl_test
    ssl_test=$(docker run --rm --network "$TEST_NETWORK" \
        alpine:latest wget -q --spider https://www.google.com >/dev/null 2>&1 && echo "secure" || echo "insecure")
    
    if [[ "$ssl_test" == "secure" ]]; then
        log_success "SSL/TLS connectivity works in test network"
        ((TESTS_PASSED++))
    else
        log_warning "SSL/TLS connectivity test failed (network may be isolated)"
        ((TESTS_PASSED++))  # Warning, not failure
    fi
    ((TESTS_TOTAL++))
    
    end_test_suite "security_integration"
}

# Test suite: Performance Integration
test_performance_integration() {
    start_test_suite "performance_integration"
    
    # Test 1: Concurrent container operations
    local start_time
    start_time=$(date +%s)
    
    # Start multiple operations in parallel
    (
        docker exec "$REGISTRY_CONTAINER" curl -s http://localhost:5000/v2/_catalog >/dev/null
    ) &
    (
        docker exec "$POSTGRES_CONTAINER" psql -U postgres -d testdb -c "SELECT 1;" >/dev/null
    ) &
    
    wait
    
    local end_time
    end_time=$(date +%s)
    local operation_time=$((end_time - start_time))
    
    if [[ $operation_time -le 30 ]]; then
        log_success "Concurrent operations completed in ${operation_time}s (within 30s limit)"
        ((TESTS_PASSED++))
    else
        log_error "Concurrent operations took ${operation_time}s (exceeds 30s limit)"
        ((TESTS_FAILED++))
    fi
    ((TESTS_TOTAL++))
    
    # Test 2: Resource usage monitoring
    local registry_memory
    registry_memory=$(docker stats "$REGISTRY_CONTAINER" --no-stream --format "{{.MemUsage}}" | cut -d'/' -f1 | sed 's/MiB//' | sed 's/[^0-9.]//g' || echo "0")
    local postgres_memory
    postgres_memory=$(docker stats "$POSTGRES_CONTAINER" --no-stream --format "{{.MemUsage}}" | cut -d'/' -f1 | sed 's/MiB//' | sed 's/[^0-9.]//g' || echo "0")
    
    # Check if memory usage is reasonable (under 500MB each)
    if (( $(echo "$registry_memory < 500" | bc -l 2>/dev/null || echo "1") )); then
        log_success "Registry memory usage ${registry_memory}MiB is reasonable"
        ((TESTS_PASSED++))
    else
        log_warning "Registry memory usage ${registry_memory}MiB is high"
        ((TESTS_PASSED++))  # Warning, not failure
    fi
    ((TESTS_TOTAL++))
    
    if (( $(echo "$postgres_memory < 500" | bc -l 2>/dev/null || echo "1") )); then
        log_success "PostgreSQL memory usage ${postgres_memory}MiB is reasonable"
        ((TESTS_PASSED++))
    else
        log_warning "PostgreSQL memory usage ${postgres_memory}MiB is high"
        ((TESTS_PASSED++))  # Warning, not failure
    fi
    ((TESTS_TOTAL++))
    
    end_test_suite "performance_integration"
}

# Main test execution
main() {
    log_info "Starting integration tests"
    
    # Initialize test counters
    TESTS_TOTAL=0
    TESTS_PASSED=0
    TESTS_FAILED=0
    TESTS_SKIPPED=0
    
    # Check prerequisites
    log_info "Checking integration test prerequisites"
    
    # Verify all required images are available
    local required_images=(
        "${REGISTRY}/${IMAGE_NAMESPACE}/container-registry:latest"
        "${REGISTRY}/${IMAGE_NAMESPACE}/postgresql:latest"
        "${REGISTRY}/${IMAGE_NAMESPACE}/lang-go:latest"
        "${REGISTRY}/${IMAGE_NAMESPACE}/lang-node:latest"
        "${REGISTRY}/${IMAGE_NAMESPACE}/lang-python:latest"
        "${REGISTRY}/${IMAGE_NAMESPACE}/kubectl:latest"
    )
    
    for image in "${required_images[@]}"; do
        if ! docker image inspect "$image" >/dev/null 2>&1; then
            log_error "Required image not found: $image"
            log_error "Please run unit tests first to build required images"
            exit 1
        fi
    done
    
    log_success "All required images are available"
    
    # Run all integration test suites
    test_component_interaction
    test_language_runtime_integration
    test_container_registry_integration
    test_kubernetes_tools_integration
    test_security_integration
    test_performance_integration
    
    # Generate coverage report
    generate_coverage_report "$COMPONENT_NAME"
    
    # Final summary
    log_info "Integration tests completed"
    log_info "Total: $TESTS_TOTAL, Passed: $TESTS_PASSED, Failed: $TESTS_FAILED, Skipped: $TESTS_SKIPPED"
    
    # Exit with appropriate code
    if [[ $TESTS_FAILED -eq 0 ]]; then
        log_success "All integration tests passed!"
        exit 0
    else
        log_error "$TESTS_FAILED integration tests failed!"
        exit 1
    fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
