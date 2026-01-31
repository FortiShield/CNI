#!/bin/bash

# Unit Tests for Base Components
# Tests the base Docker image and system configurations

set -euo pipefail

# Source the test framework
source "$(dirname "$0")/test_framework.sh"

# Test configuration
COMPONENT_NAME="base"
BASE_IMAGE="${BASE_IMAGE:-cni/base:latest}"
TEST_CONTAINER_NAME="cni-base-test-$$"

# Test data
TEMP_DIR="/tmp/base-test-$$"
mkdir -p "$TEMP_DIR"

# Cleanup function
cleanup() {
    log_info "Cleaning up test environment"
    docker rm -f "$TEST_CONTAINER_NAME" >/dev/null 2>&1 || true
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

# Test suite: Base Image Validation
test_base_image_validation() {
    start_test_suite "base_image_validation"
    
    # Test 1: Base image exists
    test_docker_image_exists "$BASE_IMAGE" "Base image should exist"
    
    # Test 2: Base image can run
    test_docker_container_runs "$BASE_IMAGE" "whoami" "Base container should run and execute commands"
    
    # Test 3: Base image size is reasonable (should be under 500MB)
    test_docker_image_size "$BASE_IMAGE" 500 "Base image size should be reasonable"
    
    end_test_suite "base_image_validation"
}

# Test suite: System Configuration
test_system_configuration() {
    start_test_suite "system_configuration"
    
    # Create a test container
    docker run --name "$TEST_CONTAINER_NAME" -d "$BASE_IMAGE" sleep 300
    
    # Wait for container to be ready
    sleep 5
    
    # Test 1: Non-root user exists
    local user_check
    user_check=$(docker exec "$TEST_CONTAINER_NAME" id -un 2>/dev/null || echo "root")
    assert_equals "appuser" "$user_check" "Non-root user should be appuser"
    
    # Test 2: User has correct UID/GID
    local user_uid
    user_uid=$(docker exec "$TEST_CONTAINER_NAME" id -u 2>/dev/null || echo "0")
    assert_equals "1000" "$user_uid" "User should have UID 1000"
    
    # Test 3: Working directory is correct
    local working_dir
    working_dir=$(docker exec "$TEST_CONTAINER_NAME" pwd 2>/dev/null || echo "/")
    assert_equals "/opt/app" "$working_dir" "Working directory should be /opt/app"
    
    # Test 4: Environment variables are set
    local lang_env
    lang_env=$(docker exec "$TEST_CONTAINER_NAME" printenv LANG 2>/dev/null || echo "")
    assert_contains "C.UTF-8" "$lang_env" "LANG should be set to C.UTF-8"
    
    # Test 5: PATH includes user bin directory
    local path_env
    path_env=$(docker exec "$TEST_CONTAINER_NAME" printenv PATH 2>/dev/null || echo "")
    assert_contains "/home/appuser/.local/bin" "$path_env" "PATH should include user bin directory"
    
    end_test_suite "system_configuration"
}

# Test suite: Essential Packages
test_essential_packages() {
    start_test_suite "essential_packages"
    
    # Create a test container
    docker run --name "$TEST_CONTAINER_NAME" -d "$BASE_IMAGE" sleep 300
    
    # Wait for container to be ready
    sleep 5
    
    # Test 1: Core utilities are available
    local core_utils=("curl" "wget" "git" "tar" "gzip" "zip")
    for util in "${core_utils[@]}"; do
        assert_command_exists "$util" "Core utility $util should be available"
    done
    
    # Test 2: Build tools are available
    local build_tools=("gcc" "g++" "make" "cmake")
    for tool in "${build_tools[@]}"; do
        assert_command_exists "$tool" "Build tool $tool should be available"
    done
    
    # Test 3: System utilities are available
    local system_utils=("vim" "nano" "htop" "lsof")
    for util in "${system_utils[@]}"; do
        assert_command_exists "$util" "System utility $util should be available"
    done
    
    # Test 4: Network tools are available
    local network_tools=("ping" "nslookup" "nc")
    for tool in "${network_tools[@]}"; do
        assert_command_exists "$tool" "Network tool $tool should be available"
    done
    
    end_test_suite "essential_packages"
}

# Test suite: Security Configuration
test_security_configuration() {
    start_test_suite "security_configuration"
    
    # Create a test container
    docker run --name "$TEST_CONTAINER_NAME" -d "$BASE_IMAGE" sleep 300
    
    # Wait for container to be ready
    sleep 5
    
    # Test 1: Container runs as non-root
    local current_user
    current_user=$(docker exec "$TEST_CONTAINER_NAME" id -u 2>/dev/null || echo "0")
    assert_not_equals "0" "$current_user" "Container should not run as root"
    
    # Test 2: User home directory exists and is owned by user
    local home_exists
    home_exists=$(docker exec "$TEST_CONTAINER_NAME" test -d /home/appuser && echo "yes" || echo "no")
    assert_equals "yes" "$home_exists" "User home directory should exist"
    
    # Test 3: App directories exist and are writable
    local app_writable
    app_writable=$(docker exec "$TEST_CONTAINER_NAME" test -w /opt/app && echo "yes" || echo "no")
    assert_equals "yes" "$app_writable" "App directory should be writable"
    
    # Test 4: SSL certificates are available
    local cert_bundle
    cert_bundle=$(docker exec "$TEST_CONTAINER_NAME" test -f /etc/ssl/certs/ca-certificates.crt && echo "yes" || echo "no")
    assert_equals "yes" "$cert_bundle" "SSL certificate bundle should be available"
    
    end_test_suite "security_configuration"
}

# Test suite: Health Check
test_health_check() {
    start_test_suite "health_check"
    
    # Test 1: Health check passes
    local health_status
    health_status=$(docker run --rm "$BASE_IMAGE" test -f /etc/passwd && test -f /etc/group && echo "healthy" || echo "unhealthy")
    assert_equals "healthy" "$health_status" "Health check should pass"
    
    end_test_suite "health_check"
}

# Test suite: Performance Benchmarks
test_performance_benchmarks() {
    start_test_suite "performance_benchmarks"
    
    # Test 1: Container startup time (should be under 10 seconds)
    local start_time
    start_time=$(date +%s)
    
    docker run --rm "$BASE_IMAGE" echo "startup_test" >/dev/null 2>&1
    
    local end_time
    end_time=$(date +%s)
    local startup_time=$((end_time - start_time))
    
    if [[ $startup_time -le 10 ]]; then
        log_success "Container startup time ${startup_time}s is within limit (10s)"
        ((TESTS_PASSED++))
    else
        log_error "Container startup time ${startup_time}s exceeds limit (10s)"
        ((TESTS_FAILED++))
    fi
    ((TESTS_TOTAL++))
    
    # Test 2: Memory usage is reasonable
    local memory_usage
    memory_usage=$(docker run --rm "$BASE_IMAGE" cat /proc/meminfo | grep MemTotal | awk '{print $2}' || echo "0")
    
    if [[ $memory_usage -gt 1000000 ]]; then  # More than 1GB available
        log_success "Memory available ${memory_usage}KB is sufficient"
        ((TESTS_PASSED++))
    else
        log_error "Memory available ${memory_usage}KB is insufficient"
        ((TESTS_FAILED++))
    fi
    ((TESTS_TOTAL++))
    
    end_test_suite "performance_benchmarks"
}

# Main test execution
main() {
    log_info "Starting base component unit tests"
    
    # Initialize test counters
    TESTS_TOTAL=0
    TESTS_PASSED=0
    TESTS_FAILED=0
    TESTS_SKIPPED=0
    
    # Run all test suites
    test_base_image_validation
    test_system_configuration
    test_essential_packages
    test_security_configuration
    test_health_check
    test_performance_benchmarks
    
    # Generate coverage report
    generate_coverage_report "$COMPONENT_NAME"
    
    # Final summary
    log_info "Base component tests completed"
    log_info "Total: $TESTS_TOTAL, Passed: $TESTS_PASSED, Failed: $TESTS_FAILED, Skipped: $TESTS_SKIPPED"
    
    # Exit with appropriate code
    if [[ $TESTS_FAILED -eq 0 ]]; then
        log_success "All base component tests passed!"
        exit 0
    else
        log_error "$TESTS_FAILED base component tests failed!"
        exit 1
    fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
