# Load versions from unified dependency management
ARG BASE_DEBIAN_VERSION=bookworm-slim
ARG PYTHON_VERSION=3.12
ARG GO_VERSION=1.22.5
ARG NODE_VERSION=20.10.0

# Import user configuration
ARG BASE_USER_UID=10001
ARG BASE_USER_GID=10001
ARG BASE_USERNAME=appuser

FROM debian:${BASE_DEBIAN_VERSION} as python-builder

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
    libffi-dev \
    libssl-dev \
    make \
    zlib1g-dev \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

# Build Python from source
ARG BUILD_DIR=/tmp/build
RUN mkdir ${BUILD_DIR} && \
    curl -fsSL https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tgz \
    | tar -xz -C ${BUILD_DIR} && \
    cd ${BUILD_DIR}/Python-${PYTHON_VERSION} && \
    ./configure --enable-shared --with-readline=editline --with-dbmliborder= --enable-optimizations && \
    make -j$(nproc) && \
    make install && \
    ldconfig && \
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
    libssl3 \
    libffi8 \
    && rm -rf /var/lib/apt/lists/*

# Copy Python from builder stage
COPY --from=python-builder /usr/local /usr/local

# Create non-root user
RUN groupadd -r -g ${BASE_USER_GID} ${BASE_USERNAME} && \
    useradd -r -m -g ${BASE_USERNAME} -u ${BASE_USER_UID} ${BASE_USERNAME}

# Set up user environment
USER ${BASE_USERNAME}
ENV PATH="/usr/local/bin:$PATH"
WORKDIR /home/${BASE_USERNAME}

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python --version || exit 1

CMD ["python"]
