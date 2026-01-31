#!/bin/bash
set -e

# Main Build Script for CNI Project
# This script orchestrates the building of all components in the project

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Configuration
DEFAULT_REGISTRY="localhost:5000"
DEFAULT_BUILD_TYPE="standard"
DEFAULT_PARALLEL_JOBS=4

REGISTRY="${REGISTRY:-$DEFAULT_REGISTRY}"
BUILD_TYPE="${BUILD_TYPE:-$DEFAULT_BUILD_TYPE}"
PARALLEL_JOBS="${PARALLEL_JOBS:-$DEFAULT_PARALLEL_JOBS}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to display usage
usage() {
    cat << EOF
Usage: $0 [options] [components...]

Options:
  --registry REGISTRY       Docker registry to push images to (default: $DEFAULT_REGISTRY)
  --build-type TYPE         Build type: standard, ubi8, all (default: $DEFAULT_BUILD_TYPE)
  --parallel JOBS           Number of parallel build jobs (default: $DEFAULT_PARALLEL_JOBS)
  --push                    Push images to registry after building
  --clean                   Clean build artifacts before building
  --help, -h                Show this help message

Components:
  base                      Build base images only
  chunks                    Build all language and tool chunks
  alpine-certificates       Build Alpine certificates container
  git-base                  Build Git base container
  cfssl-self-sign           Build CFSSL self-sign container
  kubectl                   Build kubectl container
  postgresql               Build PostgreSQL container
  container-registry       Build container registry
  all                       Build all components (default)

Examples:
  $0                        # Build all components with standard settings
  $0 --push --registry myregistry.com chunks  # Build and push chunks
  $0 --build-type ubi8 --clean all            # Clean build all UBI8 images
  $0 base chunks                                 # Build only base and chunks
EOF
}

# Function to check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if Docker is available
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed or not in PATH"
        exit 1
    fi
    
    # Check if Docker daemon is running
    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running"
        exit 1
    fi
    
    # Check available disk space
    local available_space=$(df / | awk 'NR==2 {print $4}')
    local required_space=1048576 # 1GB in KB
    
    if [[ $available_space -lt $required_space ]]; then
        log_warning "Low disk space detected. Available: $(($available_space / 1024))MB, Recommended: 1GB+"
    fi
    
    log_success "Prerequisites check passed"
}

# Function to clean build artifacts
clean_build() {
    log_info "Cleaning build artifacts..."
    
    # Remove build directory
    local build_dir="${PROJECT_ROOT}/build"
    if [[ -d "$build_dir" ]]; then
        rm -rf "$build_dir"
        log_info "Removed build directory: $build_dir"
    fi
    
    # Clean Docker
    log_info "Cleaning Docker artifacts..."
    docker system prune -f
    
    log_success "Build artifacts cleaned"
}

# Function to build base images
build_base() {
    log_info "Building base images..."
    
    local base_dir="${PROJECT_ROOT}/base"
    
    if [[ ! -d "$base_dir" ]]; then
        log_error "Base directory not found: $base_dir"
        return 1
    fi
    
    cd "$base_dir"
    
    case $BUILD_TYPE in
        "standard"|"all")
            log_info "Building standard base image..."
            docker build -t cni-base:latest .
            docker tag cni-base:latest "${REGISTRY}/cni-base:latest"
            ;;
        "ubi8"|"all")
            log_info "Building UBI8 base image..."
            docker build -f Dockerfile.ubi8 -t cni-base-ubi8:latest .
            docker tag cni-base-ubi8:latest "${REGISTRY}/cni-base-ubi8:latest"
            ;;
    esac
    
    log_success "Base images built successfully"
}

# Function to build chunks
build_chunks() {
    log_info "Building language and tool chunks..."
    
    local chunks_dir="${PROJECT_ROOT}/chunks"
    local build_failed=0
    
    if [[ ! -d "$chunks_dir" ]]; then
        log_error "Chunks directory not found: $chunks_dir"
        return 1
    fi
    
    # Function to build a single chunk
    build_single_chunk() {
        local chunk_path="$1"
        local chunk_name=$(basename "$chunk_path")
        
        log_info "Building chunk: $chunk_name"
        
        if [[ ! -f "$chunk_path/Dockerfile" ]]; then
            log_warning "No Dockerfile found in $chunk_name, skipping"
            return 0
        fi
        
        cd "$chunk_path"
        
        # Determine which Dockerfile to use
        local dockerfile="Dockerfile"
        local image_suffix=""
        
        if [[ "$BUILD_TYPE" == "ubi8" ]] && [[ -f "Dockerfile.ubi8" ]]; then
            dockerfile="Dockerfile.ubi8"
            image_suffix="-ubi8"
        fi
        
        local image_name="cni-${chunk_name}${image_suffix}:latest"
        local registry_image="${REGISTRY}/${image_name}"
        
        # Build the image
        if docker build -f "$dockerfile" -t "$image_name" .; then
            docker tag "$image_name" "$registry_image"
            log_success "Built $chunk_name successfully"
        else
            log_error "Failed to build $chunk_name"
            ((build_failed++))
        fi
    }
    
    # Export function for parallel execution
    export -f build_single_chunk
    export REGISTRY BUILD_TYPE
    
    # Build chunks in parallel
    find "$chunks_dir" -maxdepth 1 -type d -name "lang-*" -o -name "tool-*" | sort | \
    xargs -P "$PARALLEL_JOBS" -I {} bash -c 'build_single_chunk "$@"' _ {}
    
    if [[ $build_failed -gt 0 ]]; then
        log_error "$build_failed chunks failed to build"
        return 1
    fi
    
    log_success "All chunks built successfully"
}

# Function to build component
build_component() {
    local component="$1"
    local component_dir="${PROJECT_ROOT}/${component}"
    
    log_info "Building component: $component"
    
    if [[ ! -d "$component_dir" ]]; then
        log_error "Component directory not found: $component_dir"
        return 1
    fi
    
    cd "$component_dir"
    
    # Determine which Dockerfile to use
    local dockerfile="Dockerfile"
    local image_suffix=""
    
    if [[ "$BUILD_TYPE" == "ubi8" ]] && [[ -f "Dockerfile.ubi8" ]]; then
        dockerfile="Dockerfile.ubi8"
        image_suffix="-ubi8"
    fi
    
    local image_name="cni-${component}${image_suffix}:latest"
    local registry_image="${REGISTRY}/${image_name}"
    
    # Build the image
    if docker build -f "$dockerfile" -t "$image_name" .; then
        docker tag "$image_name" "$registry_image"
        log_success "Built $component successfully"
    else
        log_error "Failed to build $component"
        return 1
    fi
}

# Function to push images to registry
push_images() {
    log_info "Pushing images to registry: $REGISTRY"
    
    # Get all images with our registry prefix
    local images=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep "^${REGISTRY}/cni-" || true)
    
    if [[ -z "$images" ]]; then
        log_warning "No images found to push"
        return 0
    fi
    
    # Push images
    echo "$images" | while read -r image; do
        if [[ -n "$image" ]]; then
            log_info "Pushing $image"
            if docker push "$image"; then
                log_success "Pushed $image"
            else
                log_error "Failed to push $image"
            fi
        fi
    done
    
    log_success "Image push completed"
}

# Function to show build summary
show_build_summary() {
    log_info "Build Summary:"
    echo "=================="
    echo "Build Type: $BUILD_TYPE"
    echo "Registry: $REGISTRY"
    echo "Parallel Jobs: $PARALLEL_JOBS"
    echo ""
    echo "Built Images:"
    docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" | grep "cni-" || echo "No CNI images found"
    echo ""
    echo "Build completed at: $(date)"
}

# Main execution
main() {
    local components=()
    local push_images_flag=false
    local clean_flag=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --registry)
                REGISTRY="$2"
                shift 2
                ;;
            --build-type)
                BUILD_TYPE="$2"
                shift 2
                ;;
            --parallel)
                PARALLEL_JOBS="$2"
                shift 2
                ;;
            --push)
                push_images_flag=true
                shift
                ;;
            --clean)
                clean_flag=true
                shift
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            --*)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
            *)
                components+=("$1")
                shift
                ;;
        esac
    done
    
    # Default to all components if none specified
    if [[ ${#components[@]} -eq 0 ]]; then
        components=("all")
    fi
    
    # Validate build type
    case $BUILD_TYPE in
        standard|ubi8|all)
            ;;
        *)
            log_error "Invalid build type: $BUILD_TYPE. Must be standard, ubi8, or all"
            exit 1
            ;;
    esac
    
    log_info "Starting CNI project build..."
    log_info "Build Type: $BUILD_TYPE"
    log_info "Registry: $REGISTRY"
    log_info "Components: ${components[*]}"
    
    # Check prerequisites
    check_prerequisites
    
    # Clean if requested
    if [[ "$clean_flag" == true ]]; then
        clean_build
    fi
    
    # Build components
    local build_start_time=$(date +%s)
    local build_failed=0
    
    for component in "${components[@]}"; do
        case $component in
            "all")
                build_base || ((build_failed++))
                build_chunks || ((build_failed++))
                build_component "alpine-certificates" || ((build_failed++))
                build_component "git-base" || ((build_failed++))
                build_component "cfssl-self-sign" || ((build_failed++))
                build_component "kubectl" || ((build_failed++))
                build_component "postgresql" || ((build_failed++))
                build_component "container-registry" || ((build_failed++))
                ;;
            "base")
                build_base || ((build_failed++))
                ;;
            "chunks")
                build_chunks || ((build_failed++))
                ;;
            "alpine-certificates"|"git-base"|"cfssl-self-sign"|"kubectl"|"postgresql"|"container-registry")
                build_component "$component" || ((build_failed++))
                ;;
            *)
                log_warning "Unknown component: $component, skipping"
                ;;
        esac
    done
    
    local build_end_time=$(date +%s)
    local build_duration=$((build_end_time - build_start_time))
    
    # Push images if requested
    if [[ "$push_images_flag" == true ]]; then
        push_images
    fi
    
    # Show summary
    show_build_summary
    
    if [[ $build_failed -gt 0 ]]; then
        log_error "Build completed with $build_failed failures in ${build_duration}s"
        exit 1
    else
        log_success "Build completed successfully in ${build_duration}s"
    fi
}

# Run main function
main "$@"