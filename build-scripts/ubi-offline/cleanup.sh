#!/bin/bash
set -e

# UBI Offline Cleanup Script
# This script cleans up build artifacts and temporary files

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

echo "Starting UBI8 offline cleanup..."

# Function to remove build artifacts
cleanup_build_artifacts() {
    echo "Cleaning up build artifacts..."
    
    local build_dir="${PROJECT_ROOT}/build"
    
    if [[ -d "$build_dir" ]]; then
        echo "Removing build directory: $build_dir"
        rm -rf "$build_dir"
    else
        echo "Build directory does not exist: $build_dir"
    fi
}

# Function to clean up Docker images
cleanup_docker_images() {
    echo "Cleaning up Docker images..."
    
    # Remove temporary build images
    local temp_images=$(docker images --format "table {{.Repository}}:{{.Tag}}" | grep "ubi8-build-" | tail -n +2)
    
    if [[ -n "$temp_images" ]]; then
        echo "Removing temporary build images..."
        echo "$temp_images" | xargs -r docker rmi -f
    else
        echo "No temporary build images found"
    fi
    
    # Remove dangling images
    echo "Removing dangling images..."
    docker image prune -f
    
    # Remove unused containers
    echo "Removing unused containers..."
    docker container prune -f
}

# Function to clean up temporary containers
cleanup_temp_containers() {
    echo "Cleaning up temporary containers..."
    
    # Remove containers with specific naming pattern
    local temp_containers=$(docker ps -a --format "{{.Names}}" | grep "ubi8-build-" || true)
    
    if [[ -n "$temp_containers" ]]; then
        echo "Removing temporary containers..."
        echo "$temp_containers" | xargs -r docker rm -f
    else
        echo "No temporary containers found"
    fi
}

# Function to clean up cache
cleanup_cache() {
    echo "Cleaning up various caches..."
    
    # Clean Docker build cache
    echo "Cleaning Docker build cache..."
    docker builder prune -f
    
    # Clean system package caches if running in container
    if [[ -f /.dockerenv ]]; then
        echo "Cleaning package caches..."
        if command -v apt-get &> /dev/null; then
            apt-get clean
        fi
        if command -v microdnf &> /dev/null; then
            microdnf clean all
        fi
    fi
}

# Function to show cleanup summary
show_cleanup_summary() {
    echo "Cleanup summary:"
    
    # Show disk space usage
    echo "Disk space usage:"
    df -h | grep -E "(Filesystem|/dev/)"
    
    # Show Docker system info
    echo "Docker system info:"
    docker system df
    
    echo "Cleanup completed!"
}

# Function for deep cleanup (optional)
deep_cleanup() {
    echo "Performing deep cleanup..."
    
    # Remove all unused images (not just dangling)
    echo "Removing all unused images..."
    docker image prune -a -f
    
    # Remove all unused networks
    echo "Removing unused networks..."
    docker network prune -f
    
    # Remove all unused volumes
    echo "Removing unused volumes..."
    docker volume prune -f
    
    echo "Deep cleanup completed"
}

# Main execution
main() {
    local deep=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --deep)
                deep=true
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [--deep] [--help]"
                echo "  --deep    Perform deep cleanup (removes all unused images, networks, volumes)"
                echo "  --help    Show this help message"
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
    
    echo "Starting UBI8 offline cleanup..."
    
    cleanup_build_artifacts
    cleanup_temp_containers
    cleanup_docker_images
    cleanup_cache
    
    if [[ "$deep" == true ]]; then
        deep_cleanup
    fi
    
    show_cleanup_summary
}

# Run main function
main "$@"