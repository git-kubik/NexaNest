#!/bin/bash
# Build and push Docker images to local registry

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REGISTRY_URL="${REGISTRY_URL:-localhost:5000}"
VERSION="${VERSION:-latest}"
BUILD_ARGS="${BUILD_ARGS:-}"
SKIP_BASE="${SKIP_BASE:-false}"
SKIP_SERVICES="${SKIP_SERVICES:-false}"
PARALLEL="${PARALLEL:-false}"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if registry is accessible
check_registry() {
    if ! curl -s "http://${REGISTRY_URL}/v2/" > /dev/null 2>&1; then
        print_error "Registry not accessible at ${REGISTRY_URL}"
        print_status "Start registry with: ./scripts/registry-manage.sh start"
        exit 1
    fi
}

# Function to pull, tag and push base image
build_base_image() {
    local source_image=$1
    local target_name=$2
    local target_tag=${3:-$source_image}
    
    print_status "Processing ${source_image} -> ${target_name}"
    
    # Pull latest version
    if ! docker pull "${source_image}"; then
        print_error "Failed to pull ${source_image}"
        return 1
    fi
    
    # Tag for local registry
    local target_image="${REGISTRY_URL}/nexanest/${target_name}:${target_tag##*:}"
    docker tag "${source_image}" "${target_image}"
    
    # Push to registry
    if docker push "${target_image}"; then
        print_success "✓ ${target_name} pushed successfully"
    else
        print_error "✗ Failed to push ${target_name}"
        return 1
    fi
}

# Function to build and push service image
build_service_image() {
    local service_name=$1
    local dockerfile_path=$2
    local build_context=${3:-"services/${service_name}"}
    
    if [ ! -f "${dockerfile_path}" ]; then
        print_warning "Dockerfile not found: ${dockerfile_path} - skipping ${service_name}"
        return 0
    fi
    
    print_status "Building ${service_name} service..."
    
    local image_name="${REGISTRY_URL}/nexanest/${service_name}:${VERSION}"
    
    # Build image
    if docker build ${BUILD_ARGS} -t "${image_name}" -f "${dockerfile_path}" "${build_context}"; then
        print_success "✓ ${service_name} built successfully"
        
        # Push to registry
        if docker push "${image_name}"; then
            print_success "✓ ${service_name} pushed successfully"
        else
            print_error "✗ Failed to push ${service_name}"
            return 1
        fi
    else
        print_error "✗ Failed to build ${service_name}"
        return 1
    fi
}

# Function to show usage
show_usage() {
    echo "Build and push Docker images to local registry"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --version VERSION       Image version tag (default: latest)"
    echo "  --registry URL          Registry URL (default: localhost:5000)"
    echo "  --skip-base             Skip building base images"
    echo "  --skip-services         Skip building service images"
    echo "  --build-args ARGS       Additional build arguments"
    echo "  --help                  Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  REGISTRY_URL           Registry URL (default: localhost:5000)"
    echo "  VERSION                Image version tag (default: latest)"
    echo "  BUILD_ARGS             Additional build arguments"
    echo "  SKIP_BASE              Skip base images (true/false)"
    echo "  SKIP_SERVICES          Skip service images (true/false)"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Build all images with defaults"
    echo "  $0 --version v1.0.0                  # Build with specific version"
    echo "  $0 --skip-base                       # Build only service images"
    echo "  $0 --build-args '--no-cache'         # Build with no cache"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --version)
            VERSION="$2"
            shift 2
            ;;
        --registry)
            REGISTRY_URL="$2"
            shift 2
            ;;
        --skip-base)
            SKIP_BASE="true"
            shift
            ;;
        --skip-services)
            SKIP_SERVICES="true"
            shift
            ;;
        --build-args)
            BUILD_ARGS="$2"
            shift 2
            ;;
        --help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Main execution
print_status "🔨 Building and pushing NexaNest images"
print_status "Registry: ${REGISTRY_URL}"
print_status "Version: ${VERSION}"
print_status "Build Args: ${BUILD_ARGS}"
echo ""

# Check registry accessibility
check_registry

# Build base images
if [ "${SKIP_BASE}" != "true" ]; then
    print_status "📦 Building base images..."
    echo ""
    
    # Base images used in Swarm deployment
    build_base_image "redis:7-alpine" "redis" "7-alpine"
    build_base_image "confluentinc/cp-kafka:7.5.0" "kafka" "7.5.0"
    build_base_image "confluentinc/cp-zookeeper:7.5.0" "zookeeper" "7.5.0"
    build_base_image "kong:3.4-alpine" "kong" "3.4-alpine"
    build_base_image "opensearchproject/opensearch:2.11.0" "opensearch" "2.11.0"
    
    print_success "✅ Base images completed!"
    echo ""
else
    print_warning "⏭️  Skipping base images"
    echo ""
fi

# Build service images
if [ "${SKIP_SERVICES}" != "true" ]; then
    print_status "🚀 Building service images..."
    echo ""
    
    # Auth Service
    build_service_image "auth-service" "services/auth/Dockerfile"
    
    # Portfolio Service
    build_service_image "portfolio-service" "services/portfolio/Dockerfile"
    
    # Market Data Service
    build_service_image "market-data-service" "services/market-data/Dockerfile"
    
    # AI/ML Service
    build_service_image "ai-ml-service" "services/ai-ml/Dockerfile"
    
    # Analytics Service
    build_service_image "analytics-service" "services/analytics/Dockerfile"
    
    # Notification Service
    build_service_image "notification-service" "services/notification/Dockerfile"
    
    print_success "✅ Service images completed!"
    echo ""
else
    print_warning "⏭️  Skipping service images"
    echo ""
fi

# Build documentation
print_status "📚 Building documentation..."
if [ -f "infrastructure/docker/docs.Dockerfile" ]; then
    build_service_image "docs" "infrastructure/docker/docs.Dockerfile" "."
else
    print_warning "Documentation Dockerfile not found - skipping docs"
fi

echo ""
print_success "🎉 All builds completed successfully!"
echo ""

# Show summary
print_status "📋 Build Summary:"
echo ""
print_status "Images in registry:"
./scripts/registry-manage.sh list 2>/dev/null | grep -E "(nexanest|Repository)" || echo "No images found"

echo ""
print_status "💡 Next steps:"
echo "  1. Check images: ./scripts/registry-manage.sh list"
echo "  2. Deploy to Swarm: make deploy-swarm"
echo "  3. Check deployment: make swarm-ps"