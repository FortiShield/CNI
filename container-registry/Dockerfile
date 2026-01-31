# Container Registry based on Docker Registry
FROM debian:bookworm-slim

# Configuration
ENV REGISTRY_VERSION=2.8.2
ENV REGISTRY_STORAGE_FILESYSTEM_ROOTDIRECTORY=/var/lib/registry
ENV REGISTRY_HTTP_ADDR=0.0.0.0:5000
ENV REGISTRY_LOG_LEVEL=info
ENV REGISTRY_LOG_FORMATTER=json

# Install dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        gnupg \
        && rm -rf /var/lib/apt/lists/*

# Create registry user
RUN groupadd -r registry && \
    useradd -r -g registry -d /var/lib/registry -s /sbin/nologin registry

# Install Docker Registry
RUN curl -fsSL https://github.com/distribution/distribution/releases/download/v${REGISTRY_VERSION}/registry_${REGISTRY_VERSION}_linux_amd64.tar.gz -o registry.tar.gz && \
    tar -xzf registry.tar.gz -C /usr/local/bin && \
    rm registry.tar.gz && \
    chmod +x /usr/local/bin/registry

# Create directories
RUN mkdir -p /var/lib/registry /etc/docker/registry && \
    chown -R registry:registry /var/lib/registry /etc/docker/registry

# Copy scripts and configuration
COPY --chown=registry:registry scripts/ /scripts/
COPY --chown=registry:registry config.yml /etc/docker/registry/config.yml

# Set permissions
RUN chmod +x /scripts/healthcheck

# Expose port
EXPOSE 5000

# Switch to non-root user
USER registry

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD /scripts/healthcheck

# Default command
CMD ["registry", "serve", "/etc/docker/registry/config.yml"]