# Development Setup

This guide will help you set up your development environment for Neopilot-AI CNI.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) 20.10+
- [VS Code](https://code.visualstudio.com/)
- [Dev Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) extension
- [Git](https://git-scm.com/)

## Getting Started

### 1. Clone the Repository

```bash
git clone https://github.com/Neopilot-AI/CNI.git
cd CNI
```

### 2. Open in VS Code with Dev Container

1. Open the project in VS Code
2. Install the recommended extensions when prompted
3. Click the green button in the bottom-left corner
4. Select "Reopen in Container"

### 3. Verify Your Setup

```bash
# Check Docker is working
docker --version

# Check Go is installed
go version

# Check Node.js is installed
node --version
npm --version

# Check Python is installed
python3 --version
```

## Build System

### Building Components

```bash
# Build all components
make all

# Build a specific component
make build-<component>

# List all available targets
make help
```

### Running Tests

```bash
# Run unit tests
make test

# Run integration tests
make test-integration

# Run security scans
make security-scan
```

## Development Workflow

1. Create a new branch for your feature/bugfix:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. Make your changes

3. Run tests and verify your changes
   ```bash
   make test
   make lint
   ```

4. Commit your changes with a descriptive message
   ```bash
   git add .
   git commit -m "feat: add amazing feature"
   ```

5. Push your changes and create a Pull Request

## Debugging

### VS Code Debug Configuration

The project includes VS Code debug configurations for:

- Go applications
- Python scripts
- Node.js services

Press `F5` to start debugging the current file.

### Container Logs

```bash
# View container logs
docker-compose logs -f

# View logs for a specific service
docker-compose logs -f <service-name>
```

## Common Issues

### Container Build Failures

If you encounter build failures:

1. Ensure Docker has enough resources (4GB RAM, 2 CPUs minimum)
2. Clear Docker cache: `docker system prune -f`
3. Delete the `.devcontainer` folder and restart VS Code

### Dependency Issues

If you have dependency issues:

1. Update dependencies: `make deps-update`
2. Clear Go module cache: `go clean -modcache`
3. Rebuild containers: `docker-compose build --no-cache`

## Next Steps

- Read the [API Documentation](api/README.md)
- Check out the [Architecture Guide](architecture.md)
- Review the [Contributing Guidelines](contributing/guidelines.md)
