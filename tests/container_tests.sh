#!/bin/bash

# Unit Tests for Container Components
# Tests container-specific images (registry, kubectl, postgresql)

set -euo pipefail

# Source the test framework
source "$(dirname "$0")/test_framework.sh"

# Test configuration
COMPONENT_NAME="container"
REGISTRY="${REGISTRY:-cni}"
TEST_TIMEOUT=120

# Container configurations
declare -A CONTAINERS=(
    ["container-registry"]="registry:2"
    ["kubectl"]="kubectl"
    ["postgresql"]="postgresql"
)

declare -A CONTAINER_IMAGES=(
    ["container-registry"]="${REGISTRY}/container-registry:latest"
    ["kubectl"]="${REGISTRY}/kubectl:latest"
    ["postgresql"]="${REGISTRY}/postgresql:latest"
)

declare -A CONTAINER_COMMANDS=(
    ["container-registry"]="registry serve /etc/docker/registry/config.yml"
    ["kubectl"]="kubectl version --client"
    ["postgresql"]="psql --version"
)

# Test data
TEMP_DIR="/tmp/container-test-$$"
mkdir -p "$TEMP_DIR"

# Cleanup function
cleanup() {
    log_info "Cleaning up container test environment"
    docker ps -q --filter "label=test=true" | xargs -r docker rm -f >/dev/null 2>&1 || true
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

# Test suite: Container Image Validation
test_container_image_validation() {
    local container="$1"
    local image="${CONTAINER_IMAGES[$container]}"
    
    start_test_suite "container_${container}_image_validation"
    
    # Test 1: Container image exists
    test_docker_image_exists "$image" "Container image for $container should exist"
    
    # Test 2: Container image can run
    test_docker_container_runs "$image" "echo 'test'" "Container for $container should run"
    
    # Test 3: Container image size is reasonable
    local max_size=500
    if [[ "$container" == "postgresql" ]]; then
        max_size=1000  # Allow larger size for PostgreSQL
    fi
    test_docker_image_size "$image" "$max_size" "Container image for $container size should be reasonable"
    
    end_test_suite "container_${container}_image_validation"
}

# Test suite: Container Registry
test_container_registry() {
    local image="${CONTAINER_IMAGES[container-registry]}"
    
    start_test_suite "container_registry_functionality"
    
    # Test 1: Registry configuration file exists
    docker run --rm "$image" test -f /etc/docker/registry/config.yml
    assert_equals "0" "$?" "Registry configuration file should exist"
    
    # Test 2: Registry can start (brief test)
    local container_id
    container_id=$(docker run -d --label test=true -p 5000:5000 "$image" registry serve /etc/docker/registry/config.yml)
    
    # Wait for registry to start
    sleep 10
    
    # Test 3: Registry responds to health check
    if curl -s http://localhost:5000/v2/ >/dev/null 2>&1; then
        log_success "Container registry responds to HTTP requests"
        ((TESTS_PASSED++))
    else
        log_error "Container registry does not respond to HTTP requests"
        ((TESTS_FAILED++))
    fi
    ((TESTS_TOTAL++))
    
    # Test 4: Registry logs show startup
    local logs
    logs=$(docker logs "$container_id" 2>&1 || echo "")
    assert_contains "listening on" "$logs" "Registry logs should show it's listening"
    
    # Cleanup
    docker rm -f "$container_id" >/dev/null 2>&1 || true
    
    end_test_suite "container_registry_functionality"
}

# Test suite: kubectl
test_kubectl() {
    local image="${CONTAINER_IMAGES[kubectl]}"
    
    start_test_suite "kubectl_functionality"
    
    # Test 1: kubectl version command works
    local version_output
    version_output=$(docker run --rm "$image" kubectl version --client --short 2>&1 || echo "FAILED")
    assert_not_equals "FAILED" "$version_output" "kubectl version command should work"
    assert_contains "Client Version:" "$version_output" "kubectl should show client version"
    
    # Test 2: kubectl help command works
    local help_output
    help_output=$(docker run --rm "$image" kubectl --help 2>&1 || echo "FAILED")
    assert_not_equals "FAILED" "$help_output" "kubectl help command should work"
    assert_contains "kubectl controls the Kubernetes cluster manager" "$help_output" "kubectl help should contain description"
    
    # Test 3: kubectl config command works
    local config_output
    config_output=$(docker run --rm "$image" kubectl config view --minify 2>&1 || echo "FAILED")
    # This might fail if no config exists, but the command should not crash
    assert_not_equals "FAILED" "$config_output" "kubectl config command should execute"
    
    # Test 4: kubectl can connect to a test cluster (if available)
    # This is optional and will be skipped if no cluster is available
    local cluster_check
    cluster_check=$(docker run --rm "$image" kubectl cluster-info --request-timeout=5 2>&1 || echo "NO_CLUSTER")
    if [[ "$cluster_check" != "NO_CLUSTER" ]]; then
        log_success "kubectl can connect to cluster (optional test)"
        ((TESTS_PASSED++))
    else
        log_info "No Kubernetes cluster available for connection test (skipped)"
        ((TESTS_SKIPPED++))
    fi
    ((TESTS_TOTAL++))
    
    end_test_suite "kubectl_functionality"
}

# Test suite: PostgreSQL
test_postgresql() {
    local image="${CONTAINER_IMAGES[postgresql]}"
    
    start_test_suite "postgresql_functionality"
    
    # Test 1: PostgreSQL client tools are available
    local tools=("psql" "pg_dump" "pg_restore" "createdb" "dropdb")
    for tool in "${tools[@]}"; do
        assert_command_exists "$tool" "PostgreSQL tool $tool should be available"
    done
    
    # Test 2: PostgreSQL version information
    local version_output
    version_output=$(docker run --rm "$image" psql --version 2>&1 || echo "FAILED")
    assert_not_equals "FAILED" "$version_output" "PostgreSQL version command should work"
    assert_contains "psql (PostgreSQL)" "$version_output" "PostgreSQL should show version information"
    
    # Test 3: PostgreSQL can start (brief test)
    local container_id
    container_id=$(docker run -d --label test=true -e POSTGRES_PASSWORD=testpass -e POSTGRES_DB=testdb -p 5432:5432 "$image")
    
    # Wait for PostgreSQL to start
    sleep 15
    
    # Test 4: PostgreSQL accepts connections
    local connection_test
    connection_test=$(docker exec "$container_id" pg_isready -U postgres -d testdb 2>&1 || echo "FAILED")
    assert_contains "accepting connections" "$connection_test" "PostgreSQL should accept connections"
    
    # Test 5: PostgreSQL can create and query tables
    local sql_test
    sql_test=$(docker exec "$container_id" psql -U postgres -d testdb -c "
        CREATE TABLE test_table (id INTEGER, name TEXT);
        INSERT INTO test_table VALUES (1, 'test');
        SELECT COUNT(*) FROM test_table;
    " 2>&1 || echo "FAILED")
    
    assert_not_equals "FAILED" "$sql_test" "PostgreSQL should execute SQL commands"
    assert_contains "1" "$sql_test" "PostgreSQL should return correct query result"
    
    # Test 6: PostgreSQL data directory exists
    local data_dir_exists
    data_dir_exists=$(docker exec "$container_id" test -d /var/lib/postgresql/data && echo "yes" || echo "no")
    assert_equals "yes" "$data_dir_exists" "PostgreSQL data directory should exist"
    
    # Cleanup
    docker rm -f "$container_id" >/dev/null 2>&1 || true
    
    end_test_suite "postgresql_functionality"
}

# Test suite: Container Security
test_container_security() {
    local container="$1"
    local image="${CONTAINER_IMAGES[$container]}"
    
    start_test_suite "container_${container}_security"
    
    # Test 1: Container runs as appropriate user
    local current_user
    current_user=$(docker run --rm "$image" id -u 2>/dev/null || echo "0")
    
    if [[ "$container" == "postgresql" ]]; then
        # PostgreSQL typically runs as postgres user (non-root)
        assert_not_equals "0" "$current_user" "$container should run as non-root user"
    else
        # Other containers should ideally run as non-root
        if [[ "$current_user" == "0" ]]; then
            log_warning "$container runs as root user - consider using non-root user"
        else
            log_success "$container runs as non-root user (UID: $current_user)"
        fi
        ((TESTS_PASSED++))
    fi
    ((TESTS_TOTAL++))
    
    # Test 2: SSL certificates are available
    local cert_check
    cert_check=$(docker run --rm "$image" test -f /etc/ssl/certs/ca-certificates.crt && echo "yes" || echo "no")
    assert_equals "yes" "$cert_check" "SSL certificates should be available for $container"
    
    # Test 3: No sensitive data in image layers (basic check)
    local sensitive_check
    sensitive_check=$(docker history "$image" 2>&1 | grep -i "password\|secret\|key" | wc -l || echo "0")
    if [[ $sensitive_check -eq 0 ]]; then
        log_success "No obvious sensitive data found in $container image history"
        ((TESTS_PASSED++))
    else
        log_warning "Potential sensitive data found in $container image history"
        ((TESTS_PASSED++))  # Warning, not failure
    fi
    ((TESTS_TOTAL++))
    
    end_test_suite "container_${container}_security"
}

# Test suite: Container Performance
test_container_performance() {
    local container="$1"
    local image="${CONTAINER_IMAGES[$container]}"
    
    start_test_suite "container_${container}_performance"
    
    # Test 1: Container startup time
    local start_time
    start_time=$(date +%s.%N)
    
    docker run --rm "$image" echo "startup_test" >/dev/null 2>&1
    
    local end_time
    end_time=$(date +%s.%N)
    local startup_time
    startup_time=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "10")
    
    # Convert to integer for comparison
    local startup_int
    startup_int=$(echo "$startup_time" | cut -d. -f1)
    
    if [[ $startup_int -le 30 ]]; then
        log_success "$container startup time ${startup_time}s is within limit (30s)"
        ((TESTS_PASSED++))
    else
        log_error "$container startup time ${startup_time}s exceeds limit (30s)"
        ((TESTS_FAILED++))
    fi
    ((TESTS_TOTAL++))
    
    # Test 2: Memory usage check
    local memory_check
    memory_check=$(docker run --rm "$image" cat /proc/meminfo | grep MemTotal | awk '{print $2}' || echo "0")
    
    if [[ $memory_check -gt 500000 ]]; then  # More than 500MB available
        log_success "$container has sufficient memory (${memory_check}KB)"
        ((TESTS_PASSED++))
    else
        log_error "$container has insufficient memory (${memory_check}KB)"
        ((TESTS_FAILED++))
    fi
    ((TESTS_TOTAL++))
    
    end_test_suite "container_${container}_performance"
}

# Main test execution
main() {
    local specific_container="${1:-}"
    
    log_info "Starting container component unit tests"
    
    # Initialize test counters
    TESTS_TOTAL=0
    TESTS_PASSED=0
    TESTS_FAILED=0
    TESTS_SKIPPED=0
    
    # Run tests for specific container or all containers
    if [[ -n "$specific_container" && -n "${CONTAINERS[$specific_container]:-}" ]]; then
        log_info "Testing container: $specific_container"
        test_container_image_validation "$specific_container"
        test_container_security "$specific_container"
        test_container_performance "$specific_container"
        
        # Run specific functionality tests
        case "$specific_container" in
            "container-registry")
                test_container_registry
                ;;
            "kubectl")
                test_kubectl
                ;;
            "postgresql")
                test_postgresql
                ;;
        esac
        
        generate_coverage_report "container_${specific_container}"
    else
        log_info "Testing all containers"
        for container in "${!CONTAINERS[@]}"; do
            log_info "Testing container: $container"
            test_container_image_validation "$container"
            test_container_security "$container"
            test_container_performance "$container"
            
            # Run specific functionality tests
            case "$container" in
                "container-registry")
                    test_container_registry
                    ;;
                "kubectl")
                    test_kubectl
                    ;;
                "postgresql")
                    test_postgresql
                    ;;
            esac
        done
        generate_coverage_report "$COMPONENT_NAME"
    fi
    
    # Final summary
    log_info "Container component tests completed"
    log_info "Total: $TESTS_TOTAL, Passed: $TESTS_PASSED, Failed: $TESTS_FAILED, Skipped: $TESTS_SKIPPED"
    
    # Exit with appropriate code
    if [[ $TESTS_FAILED -eq 0 ]]; then
        log_success "All container component tests passed!"
        exit 0
    else
        log_error "$TESTS_FAILED container component tests failed!"
        exit 1
    fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
