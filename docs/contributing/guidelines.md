# Contribution Guidelines

Thank you for your interest in contributing to Neopilot-AI CNI! We welcome contributions from everyone.

## Getting Started

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Development Workflow

### Prerequisites

- Go 1.22.5+
- Docker 20.10+
- Make
- Git

### Building the Project

```bash
# Clone the repository
git clone https://github.com/Neopilot-AI/CNI.git
cd CNI

# Install dependencies
make deps

# Build all components
make all
```

### Testing

```bash
# Run unit tests
make test

# Run integration tests
make test-integration

# Run security scans
make security-scan
```

## Code Style

- Follow the [Go Code Review Comments](https://github.com/golang/go/wiki/CodeReviewComments)
- Use `gofmt` for code formatting
- Keep lines under 100 characters
- Write tests for new features
- Update documentation when adding new features

## Pull Request Process

1. Ensure tests pass
2. Update documentation if needed
3. Add your changes to the CHANGELOG.md
4. Ensure your code is properly documented
5. Request review from at least one maintainer

## Reporting Issues

When reporting issues, please include:

- Version of Neopilot-AI CNI
- Steps to reproduce
- Expected behavior
- Actual behavior
- Any relevant logs or screenshots

## Code of Conduct

Please note that this project is released with a [Code of Conduct](code-of-conduct.md). By participating in this project you agree to abide by its terms.
