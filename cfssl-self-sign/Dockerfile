# cfssl-self-sign
# 
# Container to auto-generate self-signed certificates for kubernetes
# - Generate self-signed CA
# - Generate a wild-card SSL certificate, based on that CA.
# - Expose all of the above through /output
ARG ALPINE_VERSION=3.19
FROM alpine:$ALPINE_VERSION

# Install dependencies and security updates
RUN apk update && \
    apk upgrade && \
    apk add --no-cache \
        ca-certificates \
        wget \
        openssl \
        curl \
        jq && \
    rm -rf /var/cache/apk/*

# Create non-root user for security
RUN addgroup -g 1001 -S cfssl && \
    adduser -S -D -H -u 1001 -h /tmp -s /sbin/nologin -G cfssl cfssl

# Copy scripts and set permissions
COPY --chown=cfssl:cfssl scripts/ /scripts/
RUN chmod +x /scripts/*.sh

# Create output directory with proper permissions
RUN mkdir -p /output && \
    chown cfssl:cfssl /output

# Install CFSSL
RUN /scripts/install-cfssl.sh

# Switch to non-root user
USER cfssl

# Set working directory
WORKDIR /output

VOLUME ["/output"]

# Add health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD test -f /output/ca.pem && test -f /output/wildcard.pem || exit 1

CMD ["/scripts/generate-certificates"]
