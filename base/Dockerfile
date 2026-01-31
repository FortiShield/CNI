# Base container image with essential system components
# Load versions from unified dependency management
ARG BASE_DEBIAN_VERSION=bookworm-slim
FROM debian:${BASE_DEBIAN_VERSION}

# System configuration
ARG DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8 LC_ALL=C.UTF-8 TZ=UTC

# Import version variables
ARG BASE_USER_UID=10001
ARG BASE_USER_GID=10001
ARG BASE_USERNAME=appuser

# Install base system packages
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
        # Core utilities
        ca-certificates \
        curl \
        wget \
        gnupg \
        gpg \
        unzip \
        zip \
        tar \
        gzip \
        bzip2 \
        xz-utils \
        # Build tools
        build-essential \
        gcc \
        g++ \
        make \
        cmake \
        pkg-config \
        # Development tools
        git \
        openssh-client \
        openssl \
        # System utilities
        procps \
        psmisc \
        lsof \
        htop \
        # Text editors
        vim \
        nano \
        # Network tools
        netcat-openbsd \
        iputils-ping \
        dnsutils \
        && rm -rf /var/lib/apt/lists/*

# Create non-root user for security
RUN groupadd -r -g ${BASE_USER_GID} ${BASE_USERNAME} && \
    useradd -r -m -g ${BASE_USERNAME} -u ${BASE_USER_UID} ${BASE_USERNAME} && \
    mkdir -p /home/${BASE_USERNAME}/.local/bin && \
    chown -R ${BASE_USERNAME}:${BASE_USERNAME} /home/${BASE_USERNAME}

# Create common directories
RUN mkdir -p /opt/app /opt/tools /usr/local/share/ca-certificates && \
    chown -R ${BASE_USERNAME}:${BASE_USERNAME} /opt/app /opt/tools

# Add user to PATH
ENV PATH="/home/${BASE_USERNAME}/.local/bin:/usr/local/bin:$PATH"

# Set working directory
WORKDIR /opt/app

# Switch to non-root user
USER ${BASE_USERNAME}

# Add health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD test -f /etc/passwd && test -f /etc/group || exit 1

# Default command
CMD ["/bin/bash"]