# Git Base Container

A secure, modern Git container with essential tools for Git operations, SSH, and repository management.

## Features

- **Modern Git**: Latest stable Git version built from source
- **Security**: Non-root user execution, proper SSH key management
- **Git LFS**: Large File Storage support
- **Git Secret**: Encrypted file storage for secrets
- **SSH Client**: Pre-configured for GitHub/GitLab
- **Health Checks**: Container health monitoring
- **Multi-Architecture**: Support for AMD64/ARM64

## Quick Start

### Basic Usage

```bash
docker run -it \
  -e GIT_USER_NAME="Your Name" \
  -e GIT_USER_EMAIL="your.email@example.com" \
  -v $(pwd):/workspace \
  git-base
```

### With SSH Keys

```bash
docker run -it \
  -e GIT_USER_NAME="Your Name" \
  -e GIT_USER_EMAIL="your.email@example.com" \
  -e SSH_PRIVATE_KEY="$(cat ~/.ssh/id_rsa)" \
  -v $(pwd):/workspace \
  git-base
```

### With Persistent Storage

```bash
docker run -it \
  -e GIT_USER_NAME="Your Name" \
  -e GIT_USER_EMAIL="your.email@example.com" \
  -v git-ssh:/home/gituser/.ssh \
  -v git-config:/home/gituser/.gitconfig \
  -v $(pwd):/workspace \
  git-base
```

## Environment Variables

### Required
- `GIT_USER_NAME`: Git user name
- `GIT_USER_EMAIL`: Git user email

### Optional
- `GIT_DEFAULT_BRANCH`: Default branch name (default: main)
- `GIT_PULL_REBASE`: Pull rebase behavior (default: false)
- `GIT_PUSH_AUTO_SETUP_REMOTE`: Auto setup remote tracking (default: true)
- `GIT_CREDENTIAL_HELPER`: Git credential helper
- `SSH_PRIVATE_KEY`: SSH private key content

## Build

```bash
# Build latest version
docker build -t git-base .

# Build with specific Git version
docker build --build-arg GIT_VERSION=2.43.0 -t git-base .

# Build for different architectures
docker buildx build --platform linux/amd64,linux/arm64 -t git-base .
```

## Usage Examples

### Clone a Repository

```bash
docker run -it \
  -e GIT_USER_NAME="Your Name" \
  -e GIT_USER_EMAIL="your.email@example.com" \
  -e SSH_PRIVATE_KEY="$(cat ~/.ssh/id_rsa)" \
  -v $(pwd):/workspace \
  git-base git clone git@github.com:user/repo.git
```

### Initialize a New Repository

```bash
docker run -it \
  -e GIT_USER_NAME="Your Name" \
  -e GIT_USER_EMAIL="your.email@example.com" \
  -v $(pwd):/workspace \
  git-base git init
```

### Git Operations

```bash
# Inside the container
git status
git add .
git commit -m "Initial commit"
git push origin main
```

## Security Features

- **Non-root User**: Container runs as `gituser` (UID 65534)
- **SSH Key Management**: Secure SSH key handling with proper permissions
- **Safe Directory**: Git configured for safe directory operations
- **Minimal Attack Surface**: Multi-stage build reduces final image size
- **Health Monitoring**: Built-in health checks for Git and SSH

## Included Tools

- **Git**: Latest stable version
- **Git LFS**: Large File Storage support
- **Git Secret**: Encrypted file storage
- **SSH Client**: OpenSSH client
- **OpenSSL**: Cryptographic library
- **Curl**: HTTP/HTTPS client

## Docker Compose

```yaml
version: '3.8'
services:
  git:
    build: .
    environment:
      GIT_USER_NAME: "Your Name"
      GIT_USER_EMAIL: "your.email@example.com"
    volumes:
      - ./workspace:/workspace
      - git-ssh:/home/gituser/.ssh
      - git-config:/home/gituser/.gitconfig
    working_dir: /workspace
    command: /bin/bash

volumes:
  git-ssh:
  git-config:
```

## Development

### Local Development

```bash
# Build and run
docker build -t git-base-dev .
docker run -it --rm -v $(pwd):/workspace git-base-dev

# Test with setup script
docker run -it --rm \
  -e GIT_USER_NAME="Test User" \
  -e GIT_USER_EMAIL="test@example.com" \
  -v $(pwd):/workspace \
  git-base-dev /scripts/setup-git.sh
```

### Testing

```bash
# Run basic tests
docker run --rm git-base git --version
docker run --rm git-base ssh -V
docker run --rm git-base git lfs version

# Health check test
docker run --rm --health-interval=5s git-base
```

## Configuration

### Git Configuration

The container includes sensible Git defaults:

```ini
[user]
    name = Git User
    email = gituser@example.com
[init]
    defaultBranch = main
[pull]
    rebase = false
[push]
    autoSetupRemote = true
[core]
    safeDirectory = /home/gituser
```

### SSH Configuration

Pre-configured SSH settings for common Git hosts:

```ssh-config
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_rsa
    IdentitiesOnly yes

Host gitlab.com
    HostName gitlab.com
    User git
    IdentityFile ~/.ssh/id_rsa
    IdentitiesOnly yes
```

## Troubleshooting

### Common Issues

1. **SSH Key Permissions**: Ensure SSH keys have proper permissions (600)
2. **Git Safe Directory**: Container configures safe directory automatically
3. **Repository Access**: Verify SSH keys are properly configured for remote access

### Health Check Failures

The health check verifies:
- Git installation and functionality
- SSH client availability
- Network connectivity to Git hosts

## License

MIT License - see LICENSE file for details.
