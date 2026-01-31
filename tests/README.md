# CNI Unit Test Framework

This directory contains a comprehensive unit testing framework for the CNI container build system. The framework provides standardized testing utilities, test suites for all component types, and integration testing capabilities.

## Overview

The test framework is designed to ensure quality and reliability across all CNI components:

- **Base Components**: Core system images (alpine-certificates, base, git-base, cfssl-self-sign)
- **Language Components**: Runtime environments for various programming languages
- **Container Components**: Specialized container images (registry, kubectl, postgresql)

## Test Structure

```
tests/
├── README.md                 # This file
├── test_framework.sh         # Core testing framework and utilities
├── base_tests.sh            # Unit tests for base components
├── language_tests.sh         # Unit tests for language components
├── container_tests.sh        # Unit tests for container components
├── integration_tests.sh      # Integration tests across components
└── coverage_report.sh        # Test coverage reporting
```

## Test Framework Features

### Core Capabilities

- **Standardized Assertions**: Comprehensive assertion functions for different test scenarios
- **Docker Integration**: Built-in support for testing Docker images and containers
- **Test Organization**: Suite-based test organization with proper setup/teardown
- **Coverage Reporting**: Automated coverage report generation (HTML and JSON)
- **CI/CD Integration**: Designed to work seamlessly with GitHub Actions

### Assertion Functions

- `assert_equals()` - Compare two values
- `assert_not_equals()` - Ensure values differ
- `assert_contains()` - Check substring presence
- `assert_file_exists()` - Verify file existence
- `assert_command_exists()` - Verify command availability
- `assert_service_running()` - Check service status
- `assert_http_status()` - Test HTTP endpoints
- `test_docker_image_exists()` - Verify Docker images
- `test_docker_container_runs()` - Test container execution
- `test_docker_image_size()` - Validate image sizes

## Running Tests

### Local Testing

```bash
# Run all unit tests
make test-unit

# Run tests for specific component
make test-unit-component COMPONENT=base
make test-unit-component COMPONENT=language
make test-unit-component COMPONENT=container

# Run integration tests
make test-integration

# Run all tests with coverage
make test-with-coverage

# Generate coverage report only
make test-coverage

# Quick basic functionality tests
make test-quick
```

### Manual Test Execution

```bash
# Make test scripts executable
chmod +x tests/*.sh

# Set environment variables
export REGISTRY="cni"
export IMAGE_NAMESPACE="cni"

# Run specific test suite
./tests/base_tests.sh
./tests/language_tests.sh
./tests/container_tests.sh
./tests/integration_tests.sh
```

## Test Suites

### Base Component Tests (`base_tests.sh`)

Tests the core system images:

- **Image Validation**: Existence, size, and basic functionality
- **System Configuration**: User permissions, environment variables, paths
- **Essential Packages**: Core utilities, build tools, system utilities
- **Security Configuration**: Non-root user, SSL certificates, permissions
- **Health Checks**: Container health and startup validation
- **Performance Benchmarks**: Startup time and resource usage

### Language Component Tests (`language_tests.sh`)

Tests language-specific runtime environments:

- **Runtime Validation**: Language version and package manager availability
- **Functionality Tests**: Simple program compilation and execution
- **Package Management**: Module/package installation and management
- **Security Checks**: User permissions and SSL certificate availability

Supported languages:
- Go, Node.js, Python, Rust, PHP
- Java, Ruby, C++, C#, Elixir

### Container Component Tests (`container_tests.sh`)

Tests specialized container images:

- **Container Registry**: Docker registry functionality and API
- **kubectl**: Kubernetes CLI tool validation
- **PostgreSQL**: Database functionality and connectivity

### Integration Tests (`integration_tests.sh`)

Tests end-to-end functionality:

- **Component Interaction**: Network communication between containers
- **Language Runtime Integration**: Database connectivity from different languages
- **Container Registry Integration**: Image push/pull operations
- **Kubernetes Tools Integration**: Manifest validation and generation
- **Security Integration**: User permissions and network isolation
- **Performance Integration**: Concurrent operations and resource monitoring

## Coverage Reporting

The framework generates comprehensive coverage reports:

### HTML Report
- Interactive dashboard with multiple tabs
- Component-wise test breakdown
- Success rates and progress indicators
- Responsive design for mobile viewing

### JSON Report
- Machine-readable format for CI/CD integration
- Structured data for automated processing
- Historical comparison capabilities

### Generating Reports

```bash
# Generate coverage report
./tests/coverage_report.sh

# View HTML report
open /tmp/test-results/coverage/coverage_report_$(date +%Y-%m-%d).html
```

## CI/CD Integration

The test framework is integrated into the GitHub Actions workflow:

### Unit Test Jobs
- Parallel execution of test suites
- Artifact collection for test results
- Coverage report generation and upload

### Integration Test Jobs
- End-to-end testing after successful unit tests
- Multi-component interaction validation
- Performance and security integration testing

### Quality Gates
- Test failures block pipeline progression
- Coverage thresholds enforce quality standards
- Automated reporting and notifications

## Configuration

### Environment Variables

- `REGISTRY`: Docker registry name (default: cni)
- `IMAGE_NAMESPACE`: Image namespace (default: cni)
- `TEST_RESULTS_DIR`: Test results directory (default: /tmp/test-results)
- `TEST_TIMEOUT`: Test timeout in seconds (default: 300)
- `COMPONENT_NAME`: Component name for reporting

### Test Customization

Tests can be customized by:

1. **Modifying Test Scripts**: Edit individual test files to add/remove tests
2. **Environment Configuration**: Set environment variables for different scenarios
3. **Framework Extension**: Add new assertion functions to `test_framework.sh`

## Best Practices

### Writing Tests

1. **Use Standard Assertions**: Leverage built-in assertion functions
2. **Organize in Suites**: Group related tests in logical suites
3. **Provide Clear Messages**: Use descriptive assertion messages
4. **Handle Cleanup**: Ensure proper resource cleanup
5. **Test Edge Cases**: Cover both success and failure scenarios

### Test Organization

1. **Logical Grouping**: Organize tests by functionality
2. **Independent Tests**: Ensure tests don't depend on each other
3. **Consistent Naming**: Use clear, descriptive test names
4. **Documentation**: Document complex test scenarios

### CI/CD Integration

1. **Parallel Execution**: Run tests in parallel where possible
2. **Artifact Collection**: Preserve test results for analysis
3. **Coverage Reporting**: Generate and upload coverage reports
4. **Quality Gates**: Enforce quality standards through gates

## Troubleshooting

### Common Issues

1. **Permission Denied**: Ensure test scripts are executable
2. **Docker Issues**: Verify Docker daemon is running
3. **Network Problems**: Check container network configuration
4. **Resource Limits**: Monitor system resource usage

### Debug Mode

Enable debug logging by setting:

```bash
export DEBUG=1
./tests/base_tests.sh
```

### Test Isolation

Tests are designed to be isolated but may require:

1. **Unique Names**: Use unique container/image names
2. **Cleanup**: Ensure proper resource cleanup
3. **Network Isolation**: Use dedicated test networks

## Contributing

When adding new tests:

1. **Follow Patterns**: Use existing test patterns and conventions
2. **Add Documentation**: Document new test suites and functions
3. **Update Coverage**: Ensure new tests are included in coverage reports
4. **Test Locally**: Verify tests pass before submitting

## Support

For questions or issues with the test framework:

1. Check this README for guidance
2. Review test script comments for specific details
3. Examine CI/CD logs for pipeline issues
4. Contact the development team for complex issues
