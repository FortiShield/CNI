#!/bin/bash

# CNI Unit Test Framework
# Provides standardized testing utilities for all components

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test configuration
TEST_RESULTS_DIR="${TEST_RESULTS_DIR:-/tmp/test-results}"
TEST_LOG_FILE="${TEST_LOG_FILE:-${TEST_RESULTS_DIR}/test.log}"
COVERAGE_DIR="${COVERAGE_DIR:-${TEST_RESULTS_DIR}/coverage}"
COMPONENT_NAME="${COMPONENT_NAME:-unknown}"
TEST_TIMEOUT="${TEST_TIMEOUT:-300}"

# Ensure test results directory exists
mkdir -p "${TEST_RESULTS_DIR}" "${COVERAGE_DIR}"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "${TEST_LOG_FILE}"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "${TEST_LOG_FILE}"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "${TEST_LOG_FILE}"
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "${TEST_LOG_FILE}"
}

# Test statistics
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Test assertion functions
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Assertion failed}"
    
    ((TESTS_TOTAL++))
    
    if [[ "$expected" == "$actual" ]]; then
        log_success "$message: Expected '$expected', got '$actual'"
        ((TESTS_PASSED++))
        return 0
    else
        log_error "$message: Expected '$expected', got '$actual'"
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_not_equals() {
    local not_expected="$1"
    local actual="$2"
    local message="${3:-Assertion failed}"
    
    ((TESTS_TOTAL++))
    
    if [[ "$not_expected" != "$actual" ]]; then
        log_success "$message: Expected not '$not_expected', got '$actual'"
        ((TESTS_PASSED++))
        return 0
    else
        log_error "$message: Expected not '$not_expected', got '$actual'"
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-Assertion failed}"
    
    ((TESTS_TOTAL++))
    
    if [[ "$haystack" == *"$needle"* ]]; then
        log_success "$message: String '$haystack' contains '$needle'"
        ((TESTS_PASSED++))
        return 0
    else
        log_error "$message: String '$haystack' does not contain '$needle'"
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_file_exists() {
    local file="$1"
    local message="${2:-File existence check failed}"
    
    ((TESTS_TOTAL++))
    
    if [[ -f "$file" ]]; then
        log_success "$message: File '$file' exists"
        ((TESTS_PASSED++))
        return 0
    else
        log_error "$message: File '$file' does not exist"
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_command_exists() {
    local command="$1"
    local message="${2:-Command existence check failed}"
    
    ((TESTS_TOTAL++))
    
    if command -v "$command" >/dev/null 2>&1; then
        log_success "$message: Command '$command' exists"
        ((TESTS_PASSED++))
        return 0
    else
        log_error "$message: Command '$command' does not exist"
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_service_running() {
    local service="$1"
    local message="${2:-Service running check failed}"
    
    ((TESTS_TOTAL++))
    
    if systemctl is-active --quiet "$service" 2>/dev/null || \
       docker ps --format "table {{.Names}}" | grep -q "^${service}$" 2>/dev/null; then
        log_success "$message: Service '$service' is running"
        ((TESTS_PASSED++))
        return 0
    else
        log_error "$message: Service '$service' is not running"
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_http_status() {
    local url="$1"
    local expected_status="$2"
    local message="${3:-HTTP status check failed}"
    local timeout="${4:-10}"
    
    ((TESTS_TOTAL++))
    
    local actual_status
    actual_status=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$timeout" "$url" 2>/dev/null || echo "000")
    
    if [[ "$actual_status" == "$expected_status" ]]; then
        log_success "$message: URL '$url' returned status $expected_status"
        ((TESTS_PASSED++))
        return 0
    else
        log_error "$message: URL '$url' returned status $actual_status, expected $expected_status"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Docker-specific test functions
test_docker_image_exists() {
    local image="$1"
    local message="${2:-Docker image existence check failed}"
    
    ((TESTS_TOTAL++))
    
    if docker image inspect "$image" >/dev/null 2>&1; then
        log_success "$message: Docker image '$image' exists"
        ((TESTS_PASSED++))
        return 0
    else
        log_error "$message: Docker image '$image' does not exist"
        ((TESTS_FAILED++))
        return 1
    fi
}

test_docker_container_runs() {
    local image="$1"
    local command="${2:-echo 'test'}"
    local message="${3:-Docker container run check failed}"
    
    ((TESTS_TOTAL++))
    
    if docker run --rm "$image" sh -c "$command" >/dev/null 2>&1; then
        log_success "$message: Docker container from image '$image' runs successfully"
        ((TESTS_PASSED++))
        return 0
    else
        log_error "$message: Docker container from image '$image' failed to run"
        ((TESTS_FAILED++))
        return 1
    fi
}

test_docker_image_size() {
    local image="$1"
    local max_size_mb="$2"
    local message="${3:-Docker image size check failed}"
    
    ((TESTS_TOTAL++))
    
    local size_bytes
    size_bytes=$(docker image inspect "$image" --format='{{.Size}}' 2>/dev/null || echo "0")
    local size_mb=$((size_bytes / 1024 / 1024))
    
    if [[ $size_mb -le $max_size_mb ]]; then
        log_success "$message: Docker image '$image' size ${size_mb}MB is within limit ${max_size_mb}MB"
        ((TESTS_PASSED++))
        return 0
    else
        log_error "$message: Docker image '$image' size ${size_mb}MB exceeds limit ${max_size_mb}MB"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Test suite management
start_test_suite() {
    local suite_name="$1"
    log_info "Starting test suite: $suite_name"
    echo "Test Suite: $suite_name" > "${TEST_RESULTS_DIR}/${suite_name}.results"
    echo "Started: $(date)" >> "${TEST_RESULTS_DIR}/${suite_name}.results"
}

end_test_suite() {
    local suite_name="$1"
    log_info "Ending test suite: $suite_name"
    
    echo "Completed: $(date)" >> "${TEST_RESULTS_DIR}/${suite_name}.results"
    echo "Total Tests: $TESTS_TOTAL" >> "${TEST_RESULTS_DIR}/${suite_name}.results"
    echo "Passed: $TESTS_PASSED" >> "${TEST_RESULTS_DIR}/${suite_name}.results"
    echo "Failed: $TESTS_FAILED" >> "${TEST_RESULTS_DIR}/${suite_name}.results"
    echo "Skipped: $TESTS_SKIPPED" >> "${TEST_RESULTS_DIR}/${suite_name}.results"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo "Result: PASSED" >> "${TEST_RESULTS_DIR}/${suite_name}.results"
        log_success "Test suite '$suite_name' PASSED ($TESTS_PASSED/$TESTS_TOTAL tests passed)"
        return 0
    else
        echo "Result: FAILED" >> "${TEST_RESULTS_DIR}/${suite_name}.results"
        log_error "Test suite '$suite_name' FAILED ($TESTS_FAILED/$TESTS_TOTAL tests failed)"
        return 1
    fi
}

# Test timeout wrapper
run_with_timeout() {
    local timeout_seconds="$1"
    local command="$2"
    local description="${3:-Command execution}"
    
    log_info "Running with ${timeout_seconds}s timeout: $description"
    
    if timeout "$timeout_seconds" bash -c "$command"; then
        log_success "Command completed within timeout: $description"
        return 0
    else
        local exit_code=$?
        if [[ $exit_code -eq 124 ]]; then
            log_error "Command timed out after ${timeout_seconds}s: $description"
        else
            log_error "Command failed with exit code $exit_code: $description"
        fi
        return $exit_code
    fi
}

# Coverage reporting
generate_coverage_report() {
    local component="$1"
    local coverage_file="${COVERAGE_DIR}/${component}.coverage"
    
    log_info "Generating coverage report for $component"
    
    # Create a basic coverage report structure
    cat > "$coverage_file" << EOF
# Coverage Report for $component
# Generated: $(date)

## Test Summary
- Total Tests: $TESTS_TOTAL
- Passed: $TESTS_PASSED
- Failed: $TESTS_FAILED
- Skipped: $TESTS_SKIPPED
- Success Rate: $(( TESTS_PASSED * 100 / TESTS_TOTAL ))%

## Coverage Areas
- [ ] Docker image functionality
- [ ] Security configurations
- [ ] Performance benchmarks
- [ ] Integration tests

EOF
    
    log_info "Coverage report saved to $coverage_file"
}

# Cleanup function
cleanup_test_environment() {
    log_info "Cleaning up test environment"
    
    # Remove temporary containers if any
    docker ps -q --filter "label=test=true" | xargs -r docker rm -f >/dev/null 2>&1 || true
    
    # Clean up temporary files
    find "${TEST_RESULTS_DIR}" -name "*.tmp" -delete 2>/dev/null || true
    
    log_info "Test environment cleanup completed"
}

# Export functions for use in test scripts
export -f log_info log_success log_warning log_error
export -f assert_equals assert_not_equals assert_contains assert_file_exists
export -f assert_command_exists assert_service_running assert_http_status
export -f test_docker_image_exists test_docker_container_runs test_docker_image_size
export -f start_test_suite end_test_suite run_with_timeout
export -f generate_coverage_report cleanup_test_environment

# Global variables
export TESTS_TOTAL TESTS_PASSED TESTS_FAILED TESTS_SKIPPED
export TEST_RESULTS_DIR TEST_LOG_FILE COVERAGE_DIR COMPONENT_NAME TEST_TIMEOUT

log_info "Test framework loaded successfully"
