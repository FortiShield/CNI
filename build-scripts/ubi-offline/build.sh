#!/bin/bash
set -e

# UBI Offline Build Script
# This script builds all language and tool chunks for offline UBI8 deployment

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CHUNKS_DIR="${PROJECT_ROOT}/chunks"
BUILD_DIR="${PROJECT_ROOT}/build"
ASSETS_DIR="${BUILD_DIR}/assets"

echo "Starting UBI8 offline build process..."
echo "Project root: ${PROJECT_ROOT}"
echo "Chunks directory: ${CHUNKS_DIR}"
echo "Build directory: ${BUILD_DIR}"

# Create build and assets directories
mkdir -p "${ASSETS_DIR}"

# Function to build a chunk
build_chunk() {
    local chunk_path="$1"
    local chunk_name=$(basename "$chunk_path")
    local dockerfile="${chunk_path}/Dockerfile.build.ubi8"
    
    echo "Building chunk: ${chunk_name}"
    
    if [[ ! -f "$dockerfile" ]]; then
        echo "Warning: ${dockerfile} not found, skipping ${chunk_name}"
        return 0
    fi
    
    # Build the chunk
    cd "$chunk_path"
    
    # Create a temporary container to extract assets
    local temp_image="ubi8-build-${chunk_name}"
    local temp_container="${temp_image}-container"
    
    echo "Building ${chunk_name} for UBI8..."
    docker build -f Dockerfile.build.ubi8 -t "${temp_image}" .
    
    echo "Extracting assets from ${chunk_name}..."
    docker create --name "${temp_container}" "${temp_image}"
    docker cp "${temp_container}:/assets" "${ASSETS_DIR}/${chunk_name}"
    docker rm "${temp_container}"
    docker rmi "${temp_image}"
    
    echo "Completed building ${chunk_name}"
}

# Export function for parallel execution
export -f build_chunk
export ASSETS_DIR

# Build all chunks
echo "Building all language and tool chunks..."
find "${CHUNKS_DIR}" -maxdepth 1 -type d -name "lang-*" -o -name "tool-*" | sort | while read -r chunk; do
    build_chunk "$chunk"
done

# Build base image
echo "Building base UBI8 image..."
cd "${PROJECT_ROOT}/base"
docker build -f Dockerfile.ubi8 -t ubi8-base:latest .

# Create final offline image
echo "Creating final offline UBI8 image..."
docker build -f Dockerfile.ubi8 -t cni-ubi8-offline:latest "${PROJECT_ROOT}"

echo "UBI8 offline build completed successfully!"
echo "Assets available in: ${ASSETS_DIR}"
echo "Final image: cni-ubi8-offline:latest"