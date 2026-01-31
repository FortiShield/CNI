# =============================================================================
# BuildKit Configuration for Neopilot-AI/CNI
# =============================================================================
# This configuration enables advanced build features for performance and security
# =============================================================================
# Version: 2.0.0

# Load versions from environment
source ../versions.env 2>/dev/null || true

# Enable BuildKit features
DOCKER_BUILDKIT=1
COMPOSE_DOCKER_CLI_BUILD=1

# BuildKit configuration
export DOCKER_CONFIG=/tmp/.docker-buildkit
mkdir -p $DOCKER_CONFIG

# Create BuildKit configuration with modern cache settings
cat > $DOCKER_CONFIG/buildkitd.toml << EOF
[worker.oci]
  gc = true
  gckeepstorage = 20
  [worker.oci.gcpolicy]
    keepDuration = "48h"
    maxUsedStoragePercent = 80

[registry."docker.io"]
  mirrors = ["https://mirror.gcr.io"]

[registry."ghcr.io"]
  http = false
  insecure = false

[experimental]
  cache = true

[registry."cache-registry"]
  http = false
  insecure = false
EOF

# Configure buildx for multi-platform builds with cache
docker buildx create --name cni-builder --use --bootstrap --driver docker-container \
  --config $DOCKER_CONFIG/buildkitd.toml \
  --buildkitd-flags '--allow-insecure-entitlement security.insecure' 2>/dev/null || \
docker buildx use default

# Set up build cache configuration
export BUILDKIT_INLINE_CACHE=1
export BUILDKIT_MULTI_PLATFORM=1
export BUILDKIT_CACHE_MOUNT=${BUILDKIT_CACHE_MOUNT:-type=cache,mode=0755,target=/root/.cache}

echo "✅ BuildKit configuration initialized"
echo "🔧 Builder: $(docker buildx inspect | grep 'Name' | awk '{print $2}')"
echo "🏗️  Platforms: $(docker buildx inspect | grep 'Platforms' | cut -d':' -f2 | xargs)"
echo "💾 Cache mount: $BUILDKIT_CACHE_MOUNT"
