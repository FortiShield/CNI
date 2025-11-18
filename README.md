# Alpine Certificates Container

A lightweight Docker container based on Alpine Linux that provides a bundled set of CA certificates with proper dereferencing and security hardening.

## Overview

This container creates a self-contained CA certificate bundle that can be used in environments where:
- Root access is not available
- Internet access for package installation is restricted
- Certificate files need to be localized (symlinks dereferenced)

## Features

- **Security Hardened**: Runs as non-root user with minimal attack surface
- **Modern Alpine**: Based on Alpine 3.19 with latest security updates
- **Health Checks**: Built-in health check to verify certificate bundle integrity
- **Logging**: Detailed logging for debugging and monitoring
- **Error Handling**: Robust error handling with proper exit codes

## Usage

### Build the Container

```bash
# Build with default Alpine version (3.19)
docker build -t alpine-certificates .

# Build with specific Alpine version
docker build --build-arg ALPINE_VERSION=3.18 -t alpine-certificates .
```

### Run the Container

```bash
# Basic usage
docker run --rm alpine-certificates

# Mount volumes for persistent certificates
docker run --rm \
  -v /path/to/certs:/etc/ssl/certs \
  -v /path/to/local-certs:/usr/local/share/ca-certificates \
  alpine-certificates

# Run as background service
docker run -d --name cert-bundler alpine-certificates
```

### Use as Base Image

```dockerfile
FROM alpine-certificates:latest

# Your application code here
COPY app/ /app/
CMD ["/app/run"]
```

## Container Behavior

1. **Cleanup**: Removes any existing certificate files in `/etc/ssl/certs`
2. **Update**: Runs `update-ca-certificates` to refresh the certificate store
3. **Dereference**: Converts external symlinks to local copies for portability
4. **Verify**: Ensures `ca-certificates.crt` exists before completion

## Volumes

- `/etc/ssl/certs`: System certificate directory
- `/usr/local/share/ca-certificates`: Additional certificate sources

## Health Check

The container includes a health check that verifies the presence of the bundled certificate file:

```bash
docker ps --format "table {{.Names}}\t{{.Status}}"
```

## Security Considerations

- Runs as non-root user `certuser` (UID: 1001)
- Minimal Alpine base image
- No unnecessary packages installed
- Proper file permissions set
- Read-only filesystem where possible

## Troubleshooting

### Common Issues

1. **Permission Denied**: Ensure mounted volumes have correct permissions
2. **Missing Certificates**: Check if source certificates are properly mounted
3. **Health Check Failing**: Verify `/etc/ssl/certs/ca-certificates.crt` exists

### Debug Mode

For debugging, you can override the entrypoint:

```bash
docker run --rm --entrypoint /bin/sh alpine-certificates -c "ls -la /etc/ssl/certs/"
```

## Development

### Local Testing

```bash
# Build and test locally
docker build -t alpine-certificates:test .
docker run --rm alpine-certificates:test

# Check health status
docker run --rm --health-interval=5s alpine-certificates:test sleep 30
```

### Script Testing

```bash
# Test the bundling script directly
docker run --rm --entrypoint /bin/sh alpine-certificates -c "/scripts/bundle-certificates"
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## Changelog

### v2.0.0
- Updated to Alpine 3.19
- Added security hardening (non-root user)
- Improved error handling and logging
- Added health checks
- Enhanced documentation

### v1.0.0
- Initial release with basic certificate bundling
