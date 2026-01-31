FROM mcr.microsoft.com/devcontainers/base:debian

# Install system dependencies
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
        build-essential \
        ca-certificates \
        curl \
        file \
        git-lfs \
        jq \
        make \
        openssh-client \
        pkg-config \
        python3-pip \
        shellcheck \
        unzip \
        vim \
        wget \
        zip \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Go
ARG GO_VERSION=1.22.5
RUN curl -fsSL "https://dl.google.com/go/go${GO_VERSION}.linux-amd64.tar.gz" | tar -C /usr/local -xzf - \
    && mkdir -p /home/vscode/go/bin \
    && chown -R vscode:vscode /home/vscode/go

# Install Node.js
ARG NODE_VERSION=20.10.0
RUN curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz" | tar -xJ -C /usr/local --strip-components=1 \
    && npm install -g npm@latest yarn@latest

# Install Python
ARG PYTHON_VERSION=3.12.7
RUN curl -fsSL "https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tar.xz" | tar -xJ \
    && cd Python-${PYTHON_VERSION} \
    && ./configure --enable-optimizations \
    && make -j$(nproc) altinstall \
    && cd .. \
    && rm -rf Python-${PYTHON_VERSION}* \
    && ln -s /usr/local/bin/python3.12 /usr/local/bin/python3 \
    && ln -s /usr/local/bin/pip3.12 /usr/local/bin/pip3 \
    && pip3 install --no-cache-dir --upgrade pip setuptools wheel

# Install development tools
RUN go install golang.org/x/tools/gopls@latest \
    && go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest \
    && go install github.com/securego/gosec/v2/cmd/gosec@latest \
    && npm install -g @commitlint/cli @commitlint/config-conventional \
    && pip3 install --no-cache-dir pre-commit hadolint

# Install Docker Compose
RUN curl -fsSL "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose \
    && chmod +x /usr/local/bin/docker-compose

# Configure shell
RUN echo 'export PATH="$HOME/.local/bin:$PATH"' >> /home/vscode/.bashrc \
    && echo 'export GOPATH="$HOME/go"' >> /home/vscode/.bashrc \
    && echo 'export PATH="$GOPATH/bin:$PATH"' >> /home/vscode/.bashrc \
    && echo 'export DOCKER_BUILDKIT=1' >> /home/vscode/.bashrc \
    && echo 'export COMPOSE_DOCKER_CLI_BUILD=1' >> /home/vscode/.bashrc \
    && echo 'export BUILDKIT_INLINE_CACHE=1' >> /home/vscode/.bashrc

# Create non-root user and set permissions
RUN usermod -aG docker vscode \
    && chown -R vscode:vscode /home/vscode

# Switch to non-root user
USER vscode

# Install pre-commit hooks
COPY .pre-commit-config.yaml /tmp/.pre-commit-config.yaml
RUN cd /tmp && pre-commit install-hooks \
    && rm /tmp/.pre-commit-config.yaml

WORKDIR /workspace
