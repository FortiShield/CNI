# Load versions from unified dependency management
ARG BASE_DEBIAN_VERSION=bookworm-slim
ARG PYTHON_VERSION=3.12.7
ARG GO_VERSION=1.22.5
ARG NODE_VERSION=20.10.0

# Import user configuration
ARG BASE_USER_UID=10001
ARG BASE_USER_GID=10001
ARG BASE_USERNAME=appuser

FROM debian:${BASE_DEBIAN_VERSION} as go-builder

# System configuration
ARG DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8 LC_ALL=C.UTF-8 TZ=UTC

# Install build dependencies with cache mount
RUN --mount=type=cache,target=/var/cache/apt,id=apt-cache \
    --mount=type=cache,target=/var/lib/apt,id=apt-lib \
    rm -f /var/lib/apt/lists/lock \
    && rm -f /var/cache/apt/archives/lock \
    && rm -f /var/lib/dpkg/lock* \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    curl \
    file \
    gcc \
    make \
    && rm -rf /var/lib/apt/lists/*

# Download and install Go
ARG BUILD_DIR=/tmp/build
RUN mkdir ${BUILD_DIR} && \
    curl -fsSL https://dl.google.com/go/go${GO_VERSION}.linux-amd64.tar.gz \
    | tar -xz -C ${BUILD_DIR} && \
    mv ${BUILD_DIR}/go /usr/local/go && \
    rm -rf ${BUILD_DIR}

# Final runtime image
FROM debian:${BASE_DEBIAN_VERSION}

# Import version variables
ARG BASE_USER_UID
ARG BASE_USER_GID
ARG BASE_USERNAME

# Install runtime dependencies only
RUN --mount=type=cache,target=/var/cache/apt,id=apt-cache-runtime \
    --mount=type=cache,target=/var/lib/apt,id=apt-lib-runtime \
    rm -f /var/lib/apt/lists/lock \
    && rm -f /var/cache/apt/archives/lock \
    && rm -f /var/lib/dpkg/lock* \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# Copy Go from builder stage
COPY --from=go-builder /usr/local/go /usr/local/go

# Create non-root user
RUN groupadd -r -g ${BASE_USER_GID} ${BASE_USERNAME} && \
    useradd -r -m -g ${BASE_USERNAME} -u ${BASE_USER_UID} ${BASE_USERNAME}

# Set up user environment
USER ${BASE_USERNAME}
ENV PATH="/usr/local/go/bin:$PATH"
ENV GOPATH="/home/${BASE_USERNAME}/go"
WORKDIR /home/${BASE_USERNAME}

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD go version || exit 1

CMD ["go"]