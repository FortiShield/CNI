#!/bin/sh

# Exit on any error, treat unset variables as errors
set -eu

# Default values
CFSSL_VERSION="${CFSSL_VERSION:-1.6.4}"
CFSSL_PLATFORM="${CFSSL_PLATFORM:-$(uname -s | tr '[:upper:]' '[:lower:]')-$(uname -m)}"
CFSSL_BASE_URL="https://github.com/cloudflare/cfssl/releases/download"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >&2
}

# Function to download and install cfssl
install_cfssl() {
    local binary="$1"
    local url="${CFSSL_BASE_URL}/v${CFSSL_VERSION}/${binary}_${CFSSL_PLATFORM}"
    
    log "Installing ${binary} v${CFSSL_VERSION} for ${CFSSL_PLATFORM}"
    
    # Download the binary
    if ! wget -O "/usr/local/bin/${binary}" "${url}"; then
        log "Failed to download ${binary} from ${url}"
        return 1
    fi
    
    # Make executable
    chmod +x "/usr/local/bin/${binary}"
    
    # Verify installation
    if ! command -v "${binary}" >/dev/null 2>&1; then
        log "Failed to install ${binary}"
        return 1
    fi
    
    log "Successfully installed ${binary}"
}

# Main installation
main() {
    log "Starting CFSSL installation"
    
    # Install dependencies
    log "Installing dependencies"
    apk add --no-cache \
        ca-certificates \
        wget \
        openssl \
        curl
    
    # Install CFSSL binaries
    install_cfssl "cfssl"
    install_cfssl "cfssljson"
    
    # Verify installation
    log "Verifying installation"
    cfssl version
    
    log "CFSSL installation completed successfully"
}

# Run main function
main "$@"
