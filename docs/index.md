# Neopilot-AI CNI

[![Documentation Status](https://img.shields.io/badge/docs-latest-brightgreen.svg)](https://neopilot-ai.github.io/CNI/)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![Renovate enabled](https://img.shields.io/badge/renovate-enabled-brightgreen.svg)](https://renovatebot.com/)

Neopilot-AI CNI is a comprehensive container build system for CNI (Container Network Interface) components, providing standardized Docker images for base systems, language runtimes, and specialized tools.

## Features

- **Multi-architecture** support (amd64/arm64)
- **Secure by default** with non-root user execution
- **Automated builds** with GitHub Actions
- **Dependency management** with RenovateBot
- **Comprehensive testing** including security scanning

## Quick Start

### Prerequisites

- Docker 20.10+
- Make
- Git

### Installation

```bash
# Clone the repository
git clone https://github.com/Neopilot-AI/CNI.git
cd CNI

# Build all images
make all
```

## Development

### Setting Up Development Environment

1. Install [VS Code](https://code.visualstudio.com/)
2. Install the [Dev Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) extension
3. Open the repository in VS Code
4. Click the green button in the bottom-left corner and select "Reopen in Container"

### Building a Specific Component

```bash
# Build a specific component (e.g., base image)
make build-base

# Build all components
make all
```

## Contributing

We welcome contributions! Please see our [Contributing Guidelines](contributing/guidelines.md) for details.

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

## Support

For support, please open an issue in our [GitHub repository](https://github.com/Neopilot-AI/CNI/issues).
