#!/bin/bash
set -e

# UBI Offline Preparation Script
# This script prepares the environment for UBI8 offline builds

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

echo "Preparing UBI8 offline build environment..."

# Check prerequisites
check_prerequisites() {
    echo "Checking prerequisites..."
    
    # Check if Docker is available
    if ! command -v docker &> /dev/null; then
        echo "Error: Docker is not installed or not in PATH"
        exit 1
    fi
    
    # Check if Docker daemon is running
    if ! docker info &> /dev/null; then
        echo "Error: Docker daemon is not running"
        exit 1
    fi
    
    # Check if UBI8 base image is available
    if ! docker image inspect registry.access.redhat.com/ubi8/ubi-minimal:latest &> /dev/null; then
        echo "Pulling UBI8 base image..."
        docker pull registry.access.redhat.com/ubi8/ubi-minimal:latest
    fi
    
    echo "Prerequisites check completed"
}

# Clean up previous builds
cleanup_previous_builds() {
    echo "Cleaning up previous builds..."
    
    local build_dir="${PROJECT_ROOT}/build"
    if [[ -d "$build_dir" ]]; then
        echo "Removing previous build directory: $build_dir"
        rm -rf "$build_dir"
    fi
    
    # Clean up any dangling images
    echo "Cleaning up dangling Docker images..."
    docker image prune -f
    
    echo "Cleanup completed"
}

# Create necessary directories
create_directories() {
    echo "Creating necessary directories..."
    
    local dirs=(
        "${PROJECT_ROOT}/build"
        "${PROJECT_ROOT}/build/assets"
        "${PROJECT_ROOT}/build/logs"
        "${PROJECT_ROOT}/build/temp"
    )
    
    for dir in "${dirs[@]}"; do
        mkdir -p "$dir"
        echo "Created directory: $dir"
    done
    
    echo "Directory creation completed"
}

# Validate chunk structure
validate_chunks() {
    echo "Validating chunk structure..."
    
    local chunks_dir="${PROJECT_ROOT}/chunks"
    local errors=0
    
    for chunk_dir in "$chunks_dir"/lang-* "$chunks_dir"/tool-*; do
        if [[ -d "$chunk_dir" ]]; then
            local chunk_name=$(basename "$chunk_dir")
            local dockerfile="$chunk_dir/Dockerfile"
            local build_dockerfile="$chunk_dir/Dockerfile.build.ubi8"
            
            if [[ ! -f "$dockerfile" ]]; then
                echo "Warning: Missing Dockerfile in $chunk_name"
                ((errors++))
            fi
            
            if [[ ! -f "$build_dockerfile" ]]; then
                echo "Warning: Missing Dockerfile.build.ubi8 in $chunk_name"
                ((errors++))
            fi
        fi
    done
    
    if [[ $errors -gt 0 ]]; then
        echo "Validation completed with $errors warnings"
    else
        echo "Chunk validation completed successfully"
    fi
}

# Set permissions
set_permissions() {
    echo "Setting permissions..."
    
    # Make scripts executable
    find "${SCRIPT_DIR}" -name "*.sh" -exec chmod +x {} \;
    
    # Set appropriate permissions for build directory
    chmod -R 755 "${PROJECT_ROOT}/build"
    
    echo "Permissions set"
}

# Main execution
main() {
    echo "Starting UBI8 offline preparation..."
    
    check_prerequisites
    cleanup_previous_builds
    create_directories
    validate_chunks
    set_permissions
    
    echo "UBI8 offline preparation completed successfully!"
    echo "You can now run: ${SCRIPT_DIR}/build.sh"
}

# Run main function
main "$@"