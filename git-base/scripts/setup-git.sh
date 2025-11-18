#!/bin/bash
# Git setup script for container initialization
# This script configures Git with proper settings and SSH keys

set -euo pipefail

# Logging function
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

# Function to validate environment variables
validate_env() {
    local required_vars=("GIT_USER_NAME" "GIT_USER_EMAIL")
    local missing_vars=()
    
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            missing_vars+=("$var")
        fi
    done
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        log "ERROR: Missing required environment variables: ${missing_vars[*]}"
        log "Please set GIT_USER_NAME and GIT_USER_EMAIL"
        exit 1
    fi
}

# Function to configure Git
configure_git() {
    log "Configuring Git user information..."
    
    git config --global user.name "$GIT_USER_NAME"
    git config --global user.email "$GIT_USER_EMAIL"
    git config --global init.defaultBranch "${GIT_DEFAULT_BRANCH:-main}"
    git config --global pull.rebase "${GIT_PULL_REBASE:-false}"
    git config --global push.autoSetupRemote "${GIT_PUSH_AUTO_SETUP_REMOTE:-true}"
    
    # Configure safe directory to avoid ownership warnings
    git config --global --add safe.directory /home/gituser
    
    # Configure credential helper
    if [[ -n "${GIT_CREDENTIAL_HELPER:-}" ]]; then
        git config --global credential.helper "$GIT_CREDENTIAL_HELPER"
    fi
    
    log "Git configuration completed"
    git config --global --list
}

# Function to setup SSH keys
setup_ssh() {
    log "Setting up SSH configuration..."
    
    # Create SSH config
    cat > ~/.ssh/config << 'EOF'
# SSH configuration for Git operations
Host *
    StrictHostKeyChecking accept-new
    UserKnownHostsFile ~/.ssh/known_hosts
    
# GitHub configuration
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_rsa
    IdentitiesOnly yes
    
# GitLab configuration
Host gitlab.com
    HostName gitlab.com
    User git
    IdentityFile ~/.ssh/id_rsa
    IdentitiesOnly yes
EOF
    
    chmod 600 ~/.ssh/config
    
    # Generate SSH key if not exists
    if [[ ! -f ~/.ssh/id_rsa ]]; then
        if [[ -n "${SSH_PRIVATE_KEY:-}" ]]; then
            log "Using provided SSH private key..."
            echo "$SSH_PRIVATE_KEY" > ~/.ssh/id_rsa
            chmod 600 ~/.ssh/id_rsa
        else
            log "Generating new SSH key pair..."
            ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N "" -C "$GIT_USER_EMAIL"
        fi
    fi
    
    # Set proper permissions
    chmod 700 ~/.ssh
    chmod 600 ~/.ssh/id_rsa
    chmod 644 ~/.ssh/id_rsa.pub
    
    log "SSH setup completed"
    if [[ -f ~/.ssh/id_rsa.pub ]]; then
        log "Public SSH key:"
        cat ~/.ssh/id_rsa.pub
    fi
}

# Function to initialize Git LFS
setup_git_lfs() {
    if command -v git-lfs >/dev/null 2>&1; then
        log "Initializing Git LFS..."
        git lfs install
        log "Git LFS initialized"
    else
        log "Git LFS not available, skipping"
    fi
}

# Function to validate Git installation
validate_git() {
    log "Validating Git installation..."
    
    if ! git --version >/dev/null 2>&1; then
        log "ERROR: Git is not properly installed"
        exit 1
    fi
    
    if ! ssh -V >/dev/null 2>&1; then
        log "ERROR: SSH client is not available"
        exit 1
    fi
    
    log "Git version: $(git --version)"
    log "SSH version: $(ssh -V 2>&1 | head -n1)"
    
    if command -v git-lfs >/dev/null 2>&1; then
        log "Git LFS version: $(git-lfs --version)"
    fi
    
    log "Git installation validation completed"
}

# Main execution
main() {
    log "Starting Git setup..."
    
    validate_env
    configure_git
    setup_ssh
    setup_git_lfs
    validate_git
    
    log "Git setup completed successfully"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
