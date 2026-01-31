#!/bin/bash
set -e

# Docker Image Synchronization Script
# This script synchronizes Docker images between registries and manages image distribution

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Configuration
DEFAULT_SOURCE_REGISTRY="localhost:5000"
DEFAULT_TARGET_REGISTRY="docker.io/myorg"
DEFAULT_IMAGE_PREFIX="cni-"
DEFAULT_CONCURRENT_JOBS=3
DEFAULT_RETRY_COUNT=3

SOURCE_REGISTRY="${SOURCE_REGISTRY:-$DEFAULT_SOURCE_REGISTRY}"
TARGET_REGISTRY="${TARGET_REGISTRY:-$DEFAULT_TARGET_REGISTRY}"
IMAGE_PREFIX="${IMAGE_PREFIX:-$DEFAULT_IMAGE_PREFIX}"
CONCURRENT_JOBS="${CONCURRENT_JOBS:-$DEFAULT_CONCURRENT_JOBS}"
RETRY_COUNT="${RETRY_COUNT:-$DEFAULT_RETRY_COUNT}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
}

log_debug() {
    if [[ "${DEBUG:-false}" == "true" ]]; then
        echo -e "${CYAN}[DEBUG]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
    fi
}

# Function to display usage
usage() {
    cat << EOF
Usage: $0 [options] <command> [arguments...]

Commands:
  list                       List images in source registry
  sync                       Sync images from source to target registry
  pull                       Pull images from source registry
  push                       Push images to target registry
  tag                        Tag images with new tags
  delete                     Delete images from registry
  validate                   Validate image integrity
  export                     Export images to tar files
  import                     Import images from tar files
  cleanup                    Clean up local images

Options:
  --source-registry REG      Source registry (default: $DEFAULT_SOURCE_REGISTRY)
  --target-registry REG      Target registry (default: $DEFAULT_TARGET_REGISTRY)
  --image-prefix PREFIX      Image name prefix (default: $DEFAULT_IMAGE_PREFIX)
  --concurrent JOBS          Number of concurrent jobs (default: $DEFAULT_CONCURRENT_JOBS)
  --retry-count COUNT        Number of retries for failed operations (default: $DEFAULT_RETRY_COUNT)
  --dry-run                  Show what would be done without executing
  --force                    Force overwrite existing images
  --debug                    Enable debug logging
  --help, -h                 Show this help message

Examples:
  $0 list                                    # List images in source registry
  $0 sync --dry-run                          # Show what would be synced
  $0 sync --target-registry docker.io/myorg  # Sync to Docker Hub
  $0 pull lang-python lang-go               # Pull specific images
  $0 push --force                            # Push all images with force
  $0 tag --target-registry gcr.io/project   # Tag for Google Container Registry
  $0 export --output-dir /tmp/exports       # Export images to tar files
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
    
    # Check for required tools
    local required_tools=("skopeo" "jq")
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            log_warning "$tool is not installed. Some features may not work."
        fi
    done
    
    log_success "Prerequisites check passed"
}

# Function to authenticate with registries
authenticate_registries() {
    log_info "Authenticating with registries..."
    
    # Authenticate with source registry if needed
    if [[ "$SOURCE_REGISTRY" != "localhost:5000" ]]; then
        log_info "Authenticating with source registry: $SOURCE_REGISTRY"
        if ! docker login "$SOURCE_REGISTRY" 2>/dev/null; then
            log_warning "Failed to authenticate with source registry. Public registry access may be limited."
        fi
    fi
    
    # Authenticate with target registry if needed
    if [[ "$TARGET_REGISTRY" != "docker.io/myorg" ]]; then
        log_info "Authenticating with target registry: $TARGET_REGISTRY"
        if ! docker login "$TARGET_REGISTRY" 2>/dev/null; then
            log_warning "Failed to authenticate with target registry. You may need to login manually."
        fi
    fi
    
    log_success "Registry authentication completed"
}

# Function to list images in registry
list_images() {
    local registry="$1"
    local prefix="$2"
    
    log_info "Listing images in registry: $registry"
    
    if command -v skopeo &> /dev/null; then
        # Use skopeo for better registry support
        if skopeo list-tags "docker://$registry" 2>/dev/null | jq -r '.Tags[]' | grep "^$prefix" 2>/dev/null; then
            return 0
        fi
    fi
    
    # Fallback to docker search (limited functionality)
    log_warning "Using docker search (limited functionality)"
    docker search "$registry/$prefix" --format "{{.Name}}" | head -20
}

# Function to pull image with retry
pull_image() {
    local image="$1"
    local retry=0
    
    while [[ $retry -lt $RETRY_COUNT ]]; do
        log_info "Pulling image: $image (attempt $((retry + 1))/$RETRY_COUNT)"
        
        if docker pull "$image"; then
            log_success "Pulled: $image"
            return 0
        else
            ((retry++))
            if [[ $retry -lt $RETRY_COUNT ]]; then
                log_warning "Failed to pull $image, retrying in 5 seconds..."
                sleep 5
            fi
        fi
    done
    
    log_error "Failed to pull $image after $RETRY_COUNT attempts"
    return 1
}

# Function to push image with retry
push_image() {
    local image="$1"
    local retry=0
    
    while [[ $retry -lt $RETRY_COUNT ]]; do
        log_info "Pushing image: $image (attempt $((retry + 1))/$RETRY_COUNT)"
        
        if docker push "$image"; then
            log_success "Pushed: $image"
            return 0
        else
            ((retry++))
            if [[ $retry -lt $RETRY_COUNT ]]; then
                log_warning "Failed to push $image, retrying in 5 seconds..."
                sleep 5
            fi
        fi
    done
    
    log_error "Failed to push $image after $RETRY_COUNT attempts"
    return 1
}

# Function to sync images between registries
sync_images() {
    log_info "Syncing images from $SOURCE_REGISTRY to $TARGET_REGISTRY"
    
    # Get list of images to sync
    local images=()
    if [[ $# -gt 0 ]]; then
        images=("$@")
    else
        # Get all images with prefix from source registry
        log_info "Discovering images in source registry..."
        while IFS= read -r image; do
            if [[ -n "$image" ]]; then
                images+=("$image")
            fi
        done < <(list_images "$SOURCE_REGISTRY" "$IMAGE_PREFIX")
    fi
    
    if [[ ${#images[@]} -eq 0 ]]; then
        log_warning "No images found to sync"
        return 0
    fi
    
    log_info "Found ${#images[@]} images to sync"
    
    # Function to sync single image
    sync_single_image() {
        local source_image="$1"
        local target_image="$2"
        
        log_info "Syncing: $source_image -> $target_image"
        
        # Pull from source
        if ! pull_image "$source_image"; then
            return 1
        fi
        
        # Tag for target
        local local_image="${source_image##*/}"
        if ! docker tag "$source_image" "$target_image"; then
            log_error "Failed to tag $source_image as $target_image"
            return 1
        fi
        
        # Push to target
        if ! push_image "$target_image"; then
            return 1
        fi
        
        # Clean up local image
        docker rmi "$target_image" 2>/dev/null || true
        
        log_success "Synced: $source_image -> $target_image"
    }
    
    # Export function for parallel execution
    export -f sync_single_image pull_image push_image
    export TARGET_REGISTRY RETRY_COUNT
    
    # Sync images in parallel
    local sync_failed=0
    for image in "${images[@]}"; do
        local source_full_image="$SOURCE_REGISTRY/$image"
        local target_full_image="$TARGET_REGISTRY/$image"
        
        if [[ "$DRY_RUN" == "true" ]]; then
            log_info "[DRY RUN] Would sync: $source_full_image -> $target_full_image"
        else
            if sync_single_image "$source_full_image" "$target_full_image"; then
                :
            else
                ((sync_failed++))
            fi
        fi
    done
    
    if [[ $sync_failed -gt 0 ]]; then
        log_error "Sync completed with $sync_failed failures"
        return 1
    else
        log_success "All images synced successfully"
    fi
}

# Function to validate image integrity
validate_images() {
    log_info "Validating image integrity..."
    
    local images=("$@")
    local validation_failed=0
    
    for image in "${images[@]}"; do
        log_info "Validating: $image"
        
        # Check if image exists locally
        if ! docker image inspect "$image" &> /dev/null; then
            log_warning "Image not found locally: $image"
            continue
        fi
        
        # Get image details
        local image_id=$(docker image inspect "$image" --format '{{.Id}}')
        local created=$(docker image inspect "$image" --format '{{.Created}}')
        local size=$(docker image inspect "$image" --format '{{.Size}}')
        
        log_info "Image ID: $image_id"
        log_info "Created: $created"
        log_info "Size: $((size / 1024 / 1024))MB"
        
        # Try to run a simple command to validate
        if docker run --rm "$image" echo "Validation test" &> /dev/null; then
            log_success "Valid: $image"
        else
            log_error "Invalid: $image (failed to run)"
            ((validation_failed++))
        fi
    done
    
    if [[ $validation_failed -gt 0 ]]; then
        log_error "Validation completed with $validation_failed failures"
        return 1
    else
        log_success "All images validated successfully"
    fi
}

# Function to export images to tar files
export_images() {
    local output_dir="${1:-/tmp/exports}"
    
    log_info "Exporting images to: $output_dir"
    
    mkdir -p "$output_dir"
    
    # Get all images with prefix
    local images=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep "^$IMAGE_PREFIX" || true)
    
    if [[ -z "$images" ]]; then
        log_warning "No images found to export"
        return 0
    fi
    
    local export_failed=0
    
    echo "$images" | while read -r image; do
        if [[ -n "$image" ]]; then
            local safe_name=$(echo "$image" | sed 's/[\/:]/_/g')
            local output_file="$output_dir/${safe_name}.tar"
            
            log_info "Exporting: $image -> $output_file"
            
            if docker save -o "$output_file" "$image"; then
                log_success "Exported: $image"
            else
                log_error "Failed to export: $image"
                ((export_failed++))
            fi
        fi
    done
    
    log_info "Export completed. Files saved to: $output_dir"
}

# Function to import images from tar files
import_images() {
    local import_dir="$1"
    
    log_info "Importing images from: $import_dir"
    
    if [[ ! -d "$import_dir" ]]; then
        log_error "Import directory not found: $import_dir"
        return 1
    fi
    
    local import_failed=0
    
    for tar_file in "$import_dir"/*.tar; do
        if [[ -f "$tar_file" ]]; then
            log_info "Importing: $tar_file"
            
            if docker load -i "$tar_file"; then
                log_success "Imported: $tar_file"
            else
                log_error "Failed to import: $tar_file"
                ((import_failed++))
            fi
        fi
    done
    
    if [[ $import_failed -gt 0 ]]; then
        log_error "Import completed with $import_failed failures"
        return 1
    else
        log_success "All images imported successfully"
    fi
}

# Function to clean up local images
cleanup_images() {
    log_info "Cleaning up local images..."
    
    # Remove dangling images
    log_info "Removing dangling images..."
    docker image prune -f
    
    # Remove images with our prefix (if force is enabled)
    if [[ "$FORCE" == "true" ]]; then
        log_info "Removing images with prefix: $IMAGE_PREFIX"
        docker images --format "{{.Repository}}:{{.Tag}}" | grep "^$IMAGE_PREFIX" | xargs -r docker rmi -f
    fi
    
    log_success "Cleanup completed"
}

# Main execution
main() {
    local command=""
    local dry_run=false
    local force=false
    local output_dir=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --source-registry)
                SOURCE_REGISTRY="$2"
                shift 2
                ;;
            --target-registry)
                TARGET_REGISTRY="$2"
                shift 2
                ;;
            --image-prefix)
                IMAGE_PREFIX="$2"
                shift 2
                ;;
            --concurrent)
                CONCURRENT_JOBS="$2"
                shift 2
                ;;
            --retry-count)
                RETRY_COUNT="$2"
                shift 2
                ;;
            --dry-run)
                dry_run=true
                shift
                ;;
            --force)
                force=true
                shift
                ;;
            --debug)
                export DEBUG=true
                shift
                ;;
            --output-dir)
                output_dir="$2"
                shift 2
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            list|sync|pull|push|tag|delete|validate|export|import|cleanup)
                command="$1"
                shift
                ;;
            *)
                log_error "Unknown option or command: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    # Set global variables
    export DRY_RUN="$dry_run"
    export FORCE="$force"
    
    # Check prerequisites
    check_prerequisites
    
    # Authenticate with registries
    authenticate_registries
    
    # Execute command
    case $command in
        "list")
            list_images "$SOURCE_REGISTRY" "$IMAGE_PREFIX"
            ;;
        "sync")
            sync_images "$@"
            ;;
        "pull")
            if [[ $# -eq 0 ]]; then
                log_error "No images specified for pull"
                exit 1
            fi
            for image in "$@"; do
                pull_image "$SOURCE_REGISTRY/$image"
            done
            ;;
        "push")
            if [[ $# -eq 0 ]]; then
                # Push all images with prefix
                local images=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep "^$IMAGE_PREFIX" || true)
                echo "$images" | while read -r image; do
                    if [[ -n "$image" ]]; then
                        push_image "$TARGET_REGISTRY/${image##*/}"
                    fi
                done
            else
                for image in "$@"; do
                    push_image "$TARGET_REGISTRY/$image"
                done
            fi
            ;;
        "validate")
            if [[ $# -eq 0 ]]; then
                local images=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep "^$IMAGE_PREFIX" || true)
                validate_images $images
            else
                validate_images "$@"
            fi
            ;;
        "export")
            export_images "$output_dir"
            ;;
        "import")
            if [[ -z "$output_dir" ]]; then
                output_dir="/tmp/exports"
            fi
            import_images "$output_dir"
            ;;
        "cleanup")
            cleanup_images
            ;;
        *)
            log_error "No command specified"
            usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"