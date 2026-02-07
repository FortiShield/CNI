# Load versions from unified dependency management
ARG BASE_DEBIAN_VERSION=bookworm-slim
ARG PYTHON_VERSION=3.12.7
ARG GO_VERSION=1.22.5
ARG NODE_VERSION=20.10.0

# Import user configuration
ARG BASE_USER_UID=10001
ARG BASE_USER_GID=10001
ARG BASE_USERNAME=appuser

FROM debian:${BASE_DEBIAN_VERSION} AS node-builder

# System configuration
ARG DEBIAN_FRONTEND=noninteractive
ARG NODE_VERSION
ENV LANG=C.UTF-8 LC_ALL=C.UTF-8 TZ=UTC

# Install build dependencies with cache mount
RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    curl \
    file \
    gcc \
    g++ \
    make \
    python3

# Download and install Node.js
ARG BUILD_DIR=/tmp/build
ARG TARGETARCH
RUN mkdir -p ${BUILD_DIR} && \
    NODE_ARCH=$(case ${TARGETARCH:-amd64} in \
    amd64) echo "x64" ;; \
    arm64) echo "arm64" ;; \
    *) echo "x64" ;; \
    esac) && \
    curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${NODE_ARCH}.tar.gz" \
    | tar -xzf - -C ${BUILD_DIR} && \
    mv ${BUILD_DIR}/node-v${NODE_VERSION}-linux-${NODE_ARCH} /usr/local/node && \
    rm -rf ${BUILD_DIR}

# Final runtime image
FROM debian:${BASE_DEBIAN_VERSION}

# Import version variables
ARG BASE_USER_UID
ARG BASE_USER_GID
ARG BASE_USERNAME

# Install runtime dependencies only
RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy Node.js from builder stage
COPY --from=node-builder /usr/local/node /usr/local/node

# Create symbolic links for Node.js tools
RUN ln -s /usr/local/node/bin/node /usr/local/bin/node && \
    ln -s /usr/local/node/bin/npm /usr/local/bin/npm && \
    ln -s /usr/local/node/bin/npx /usr/local/bin/npx

# Create non-root user
RUN groupadd -r -g ${BASE_USER_GID} ${BASE_USERNAME} && \
    useradd -r -m -g ${BASE_USERNAME} -u ${BASE_USER_UID} ${BASE_USERNAME}

# Set up user environment
USER ${BASE_USERNAME}
ENV PATH="/usr/local/node/bin:/usr/local/bin:$PATH"
WORKDIR /home/${BASE_USERNAME}

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD node --version && npm --version || exit 1

CMD ["node"]
