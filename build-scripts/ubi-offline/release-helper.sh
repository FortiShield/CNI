#!/bin/bash
set -e

# UBI Offline Release Helper Script
# This script helps with creating releases and managing versions

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Default values
DEFAULT_VERSION="1.0.0"
DEFAULT_REGISTRY="localhost:5000"
DEFAULT_IMAGE_NAME="cni-ubi8-offline"

# Configuration
VERSION="${VERSION:-$DEFAULT_VERSION}"
REGISTRY="${REGISTRY:-$DEFAULT_REGISTRY}"
IMAGE_NAME="${IMAGE_NAME:-$DEFAULT_IMAGE_NAME}"

echo "UBI8 Offline Release Helper"
echo "Version: $VERSION"
echo "Registry: $REGISTRY"
echo "Image Name: $IMAGE_NAME"

# Function to validate build before release
validate_release() {
    echo "Validating build for release..."
    
    # Check if build directory exists
    local build_dir="${PROJECT_ROOT}/build"
    if [[ ! -d "$build_dir" ]]; then
        echo "Error: Build directory not found. Run build.sh first."
        exit 1
    fi
    
    # Check if final image exists
    if ! docker image inspect "${IMAGE_NAME}:latest" &> /dev/null; then
        echo "Error: Final image not found. Run build.sh first."
        exit 1
    fi
    
    # Check assets
    local assets_dir="${build_dir}/assets"
    if [[ ! -d "$assets_dir" ]] || [[ -z "$(ls -A "$assets_dir" 2>/dev/null)" ]]; then
        echo "Error: No assets found. Build may have failed."
        exit 1
    fi
    
    echo "Release validation passed"
}

# Function to tag images for release
tag_release() {
    echo "Tagging images for release..."
    
    # Tag with version
    docker tag "${IMAGE_NAME}:latest" "${IMAGE_NAME}:${VERSION}"
    
    # Tag with registry
    docker tag "${IMAGE_NAME}:latest" "${REGISTRY}/${IMAGE_NAME}:latest"
    docker tag "${IMAGE_NAME}:latest" "${REGISTRY}/${IMAGE_NAME}:${VERSION}"
    
    echo "Images tagged successfully"
}

# Function to push to registry
push_release() {
    echo "Pushing images to registry..."
    
    # Push versioned tag
    docker push "${REGISTRY}/${IMAGE_NAME}:${VERSION}"
    
    # Push latest tag
    docker push "${REGISTRY}/${IMAGE_NAME}:latest"
    
    echo "Images pushed to registry"
}

# Function to create release manifest
create_manifest() {
    echo "Creating release manifest..."
    
    local manifest_file="${PROJECT_ROOT}/build/release-manifest-${VERSION}.json"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    cat > "$manifest_file" << EOF
{
  "version": "${VERSION}",
  "timestamp": "${timestamp}",
  "image": {
    "name": "${IMAGE_NAME}",
    "registry": "${REGISTRY}",
    "tags": ["latest", "${VERSION}"]
  },
  "chunks": [
EOF
    
    # Add chunk information
    local chunks_dir="${PROJECT_ROOT}/chunks"
    local first=true
    
    for chunk_dir in "$chunks_dir"/lang-* "$chunks_dir"/tool-*; do
        if [[ -d "$chunk_dir" ]]; then
            local chunk_name=$(basename "$chunk_dir")
            if [[ "$first" == true ]]; then
                first=false
            else
                echo "," >> "$manifest_file"
            fi
            echo "    {\"name\": \"${chunk_name}\", \"type\": \"$(echo "$chunk_name" | cut -d'-' -f1)\"}" >> "$manifest_file"
        fi
    done
    
    cat >> "$manifest_file" << EOF

  ],
  "build_info": {
    "base_image": "registry.access.redhat.com/ubi8/ubi-minimal:latest",
    "build_date": "${timestamp}",
    "git_commit": "$(git rev-parse HEAD 2>/dev/null || echo 'unknown')",
    "git_branch": "$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'unknown')"
  }
}
EOF
    
    echo "Release manifest created: $manifest_file"
}

# Function to create release archive
create_archive() {
    echo "Creating release archive..."
    
    local archive_name="${IMAGE_NAME}-${VERSION}"
    local archive_dir="${PROJECT_ROOT}/build/${archive_name}"
    local archive_file="${PROJECT_ROOT}/build/${archive_name}.tar.gz"
    
    # Create archive directory
    mkdir -p "$archive_dir"
    
    # Copy essential files
    cp -r "${PROJECT_ROOT}/build/assets" "$archive_dir/"
    cp "${PROJECT_ROOT}/build/release-manifest-${VERSION}.json" "$archive_dir/"
    
    # Copy documentation
    if [[ -f "${PROJECT_ROOT}/README.md" ]]; then
        cp "${PROJECT_ROOT}/README.md" "$archive_dir/"
    fi
    
    # Copy build scripts
    mkdir -p "$archive_dir/scripts"
    cp -r "${SCRIPT_DIR}"/*.sh "$archive_dir/scripts/"
    
    # Create archive
    cd "${PROJECT_ROOT}/build"
    tar -czf "$archive_file" "$archive_name"
    
    echo "Release archive created: $archive_file"
}

# Function to show release info
show_release_info() {
    echo "Release Information:"
    echo "=================="
    echo "Version: $VERSION"
    echo "Registry: $REGISTRY"
    echo "Image: $IMAGE_NAME"
    echo "Tags: latest, $VERSION"
    echo ""
    echo "Docker pull commands:"
    echo "  docker pull ${REGISTRY}/${IMAGE_NAME}:latest"
    echo "  docker pull ${REGISTRY}/${IMAGE_NAME}:${VERSION}"
    echo ""
    echo "Local images:"
    docker images | grep "$IMAGE_NAME" || echo "No local images found"
}

# Function to clean up release artifacts
cleanup_release() {
    echo "Cleaning up release artifacts..."
    
    # Remove temporary tags
    docker rmi "${IMAGE_NAME}:${VERSION}" 2>/dev/null || true
    docker rmi "${REGISTRY}/${IMAGE_NAME}:latest" 2>/dev/null || true
    docker rmi "${REGISTRY}/${IMAGE_NAME}:${VERSION}" 2>/dev/null || true
    
    echo "Release cleanup completed"
}

# Main execution
main() {
    local action="all"
    local push=false
    local archive=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --version)
                VERSION="$2"
                shift 2
                ;;
            --registry)
                REGISTRY="$2"
                shift 2
                ;;
            --image-name)
                IMAGE_NAME="$2"
                shift 2
                ;;
            --push)
                push=true
                shift
                ;;
            --archive)
                archive=true
                shift
                ;;
            --validate-only)
                action="validate"
                shift
                ;;
            --tag-only)
                action="tag"
                shift
                ;;
            --cleanup)
                action="cleanup"
                shift
                ;;
            --info)
                action="info"
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [options]"
                echo "Options:"
                echo "  --version VERSION    Set version (default: $DEFAULT_VERSION)"
                echo "  --registry REGISTRY  Set registry (default: $DEFAULT_REGISTRY)"
                echo "  --image-name NAME    Set image name (default: $DEFAULT_IMAGE_NAME)"
                echo "  --push              Push to registry after tagging"
                echo "  --archive           Create release archive"
                echo "  --validate-only     Only validate build"
                echo "  --tag-only          Only tag images"
                echo "  --cleanup           Clean up release artifacts"
                echo "  --info              Show release information"
                echo "  --help              Show this help"
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
    
    case $action in
        validate)
            validate_release
            ;;
        tag)
            validate_release
            tag_release
            ;;
        cleanup)
            cleanup_release
            ;;
        info)
            show_release_info
            ;;
        all)
            validate_release
            tag_release
            create_manifest
            
            if [[ "$push" == true ]]; then
                push_release
            fi
            
            if [[ "$archive" == true ]]; then
                create_archive
            fi
            
            show_release_info
            ;;
    esac
}

# Run main function
main "$@"