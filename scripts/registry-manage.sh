#!/bin/bash

# NexaNest Docker Registry Management Script
# Manages local Docker registry operations

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Registry configuration
REGISTRY_HOST=${REGISTRY_HOST:-localhost}
REGISTRY_PORT=${REGISTRY_PORT:-5000}
REGISTRY_URL="${REGISTRY_HOST}:${REGISTRY_PORT}"
REGISTRY_CONTAINER="nexanest-registry"

# Remote Docker configuration
DOCKER_HOST_IP=${DOCKER_HOST_IP:-}
REMOTE_MODE=${REMOTE_MODE:-false}

# If DOCKER_HOST environment variable is set, we're in remote mode
if [ -n "$DOCKER_HOST" ] && [ "$DOCKER_HOST" != "unix:///var/run/docker.sock" ]; then
    REMOTE_MODE=true
    # Extract IP from DOCKER_HOST (format: tcp://IP:PORT)
    if [ -z "$DOCKER_HOST_IP" ]; then
        DOCKER_HOST_IP=$(echo "$DOCKER_HOST" | sed 's|tcp://||' | sed 's|:.*||')
    fi
    # Update registry host to match Docker host
    REGISTRY_HOST="$DOCKER_HOST_IP"
    REGISTRY_URL="${REGISTRY_HOST}:${REGISTRY_PORT}"
fi

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

# Function to check if registry is running
check_registry() {
    if curl -s "http://${REGISTRY_URL}/v2/" > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to start registry
start_registry() {
    print_status "Starting Docker registry..."
    
    if check_registry; then
        print_warning "Registry is already running at ${REGISTRY_URL}"
        return 0
    fi
    
    # Remove existing container if it exists
    if docker ps -a --filter "name=${REGISTRY_CONTAINER}" --format "{{.Names}}" | grep -q "${REGISTRY_CONTAINER}"; then
        print_status "Removing existing registry container..."
        docker rm -f "${REGISTRY_CONTAINER}"
    fi
    
    # Start new registry
    docker run -d \
        --restart=always \
        --name "${REGISTRY_CONTAINER}" \
        -p "${REGISTRY_PORT}:5000" \
        -v nexanest-registry:/var/lib/registry \
        registry:2
    
    print_status "Waiting for registry to start..."
    sleep 5
    
    if check_registry; then
        print_success "Registry started successfully at ${REGISTRY_URL}"
    else
        print_error "Failed to start registry"
        exit 1
    fi
}

# Function to stop registry
stop_registry() {
    print_status "Stopping Docker registry..."
    
    if docker ps --filter "name=${REGISTRY_CONTAINER}" --format "{{.Names}}" | grep -q "${REGISTRY_CONTAINER}"; then
        docker stop "${REGISTRY_CONTAINER}"
        print_success "Registry stopped"
    else
        print_warning "Registry is not running"
    fi
}

# Function to remove registry (including data)
remove_registry() {
    print_warning "This will remove the registry container and all stored images!"
    read -p "Are you sure? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Operation cancelled"
        return 0
    fi
    
    # Stop and remove container
    if docker ps -a --filter "name=${REGISTRY_CONTAINER}" --format "{{.Names}}" | grep -q "${REGISTRY_CONTAINER}"; then
        docker rm -f "${REGISTRY_CONTAINER}"
        print_success "Registry container removed"
    fi
    
    # Remove volume
    if docker volume ls --format "{{.Name}}" | grep -q "nexanest-registry"; then
        docker volume rm nexanest-registry
        print_success "Registry volume removed"
    fi
}

# Function to show registry status
show_status() {
    print_status "Registry Status:"
    if [ "$REMOTE_MODE" = "true" ]; then
        print_status "Remote Docker Host: $DOCKER_HOST_IP"
        print_status "Docker Host: $DOCKER_HOST"
    fi
    echo ""
    
    if check_registry; then
        print_success "Registry is running at ${REGISTRY_URL}"
        
        # Show container info
        docker ps --filter "name=${REGISTRY_CONTAINER}" --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
        
        echo ""
        print_status "Registry statistics:"
        
        # Show storage usage
        if docker volume ls --format "{{.Name}}" | grep -q "nexanest-registry"; then
            echo "  Volume: nexanest-registry"
            docker system df -v | grep nexanest-registry || echo "  Size: (unable to determine)"
        fi
        
        # Show image count
        echo ""
        catalog_response=$(curl -s "http://${REGISTRY_URL}/v2/_catalog" || echo '{"repositories":[]}')
        repo_count=$(echo "$catalog_response" | python3 -c "import sys, json; print(len(json.load(sys.stdin)['repositories']))" 2>/dev/null || echo "0")
        echo "  Repositories: $repo_count"
        
    else
        print_error "Registry is not running"
    fi
}

# Function to list images in registry
list_images() {
    if ! check_registry; then
        print_error "Registry is not running"
        exit 1
    fi
    
    print_status "Images in registry:"
    echo ""
    
    catalog=$(curl -s "http://${REGISTRY_URL}/v2/_catalog")
    repositories=$(echo "$catalog" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for repo in data.get('repositories', []):
        print(repo)
except:
    pass
" 2>/dev/null)
    
    if [ -z "$repositories" ]; then
        print_warning "No images found in registry"
        return 0
    fi
    
    for repo in $repositories; do
        print_status "Repository: $repo"
        
        # Get tags for this repository
        tags=$(curl -s "http://${REGISTRY_URL}/v2/${repo}/tags/list" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    tags = data.get('tags', [])
    if tags:
        for tag in sorted(tags):
            print(f'  {tag}')
    else:
        print('  (no tags)')
except:
    print('  (error reading tags)')
" 2>/dev/null)
        
        echo "$tags"
        echo ""
    done
}

# Function to cleanup old images
cleanup_images() {
    print_warning "This will remove old/unused images from the registry!"
    read -p "Are you sure? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Operation cancelled"
        return 0
    fi
    
    if ! check_registry; then
        print_error "Registry is not running"
        exit 1
    fi
    
    print_status "Running garbage collection on registry..."
    docker exec "${REGISTRY_CONTAINER}" bin/registry garbage-collect /etc/docker/registry/config.yml
    print_success "Cleanup completed"
}

# Function to configure Docker daemon for insecure registry
configure_docker() {
    print_status "Docker daemon configuration for insecure registry:"
    echo ""
    echo "Add the following to your Docker daemon configuration:"
    echo ""
    echo "  {"
    echo "    \"insecure-registries\": [\"${REGISTRY_URL}\"]"
    echo "  }"
    echo ""
    echo "Configuration file locations:"
    echo "  - Linux: /etc/docker/daemon.json"
    echo "  - macOS: ~/.docker/daemon.json or Docker Desktop > Settings > Docker Engine"
    echo "  - Windows: %USERPROFILE%\\.docker\\daemon.json or Docker Desktop > Settings > Docker Engine"
    echo ""
    echo "After updating the configuration, restart Docker daemon."
    echo ""
    print_warning "Note: In production, use TLS certificates instead of insecure registry!"
}

# Function to test registry connectivity
test_registry() {
    print_status "Testing registry connectivity..."
    
    if ! check_registry; then
        print_error "Registry is not accessible at ${REGISTRY_URL}"
        exit 1
    fi
    
    # Test basic operations
    print_status "Testing basic API endpoints..."
    
    # Test catalog endpoint
    if curl -s "http://${REGISTRY_URL}/v2/_catalog" > /dev/null; then
        print_success "✓ Catalog endpoint working"
    else
        print_error "✗ Catalog endpoint failed"
    fi
    
    # Test with a small image push/pull
    print_status "Testing image push/pull..."
    
    # Pull a tiny image and tag it for our registry
    docker pull hello-world:latest
    docker tag hello-world:latest "${REGISTRY_URL}/test/hello-world:latest"
    
    # Try to push it
    if docker push "${REGISTRY_URL}/test/hello-world:latest" > /dev/null 2>&1; then
        print_success "✓ Image push working"
        
        # Try to pull it back
        docker rmi "${REGISTRY_URL}/test/hello-world:latest" > /dev/null 2>&1 || true
        if docker pull "${REGISTRY_URL}/test/hello-world:latest" > /dev/null 2>&1; then
            print_success "✓ Image pull working"
            
            # Cleanup test image
            docker rmi "${REGISTRY_URL}/test/hello-world:latest" > /dev/null 2>&1 || true
        else
            print_error "✗ Image pull failed"
        fi
    else
        print_error "✗ Image push failed - check Docker daemon configuration"
        print_status "Run './scripts/registry-manage.sh configure' for setup instructions"
    fi
    
    # Cleanup
    docker rmi hello-world:latest > /dev/null 2>&1 || true
}

# Function to show help
show_help() {
    echo "NexaNest Docker Registry Management"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  start       Start the Docker registry"
    echo "  stop        Stop the Docker registry"
    echo "  restart     Restart the Docker registry"
    echo "  remove      Remove registry container and data"
    echo "  status      Show registry status and statistics"
    echo "  list        List all images in the registry"
    echo "  cleanup     Remove unused images from registry"
    echo "  configure   Show Docker daemon configuration instructions"
    echo "  test        Test registry connectivity and operations"
    echo "  help        Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 start                    # Start the registry"
    echo "  $0 status                   # Check registry status"
    echo "  $0 list                     # List all stored images"
    echo "  $0 test                     # Test registry functionality"
    echo ""
    echo "Environment Variables:"
    echo "  REGISTRY_HOST=${REGISTRY_HOST}     # Registry hostname"
    echo "  REGISTRY_PORT=${REGISTRY_PORT}           # Registry port"
}

# Main script logic
case "${1:-help}" in
    start)
        start_registry
        ;;
    stop)
        stop_registry
        ;;
    restart)
        stop_registry
        sleep 2
        start_registry
        ;;
    remove)
        remove_registry
        ;;
    status)
        show_status
        ;;
    list)
        list_images
        ;;
    cleanup)
        cleanup_images
        ;;
    configure)
        configure_docker
        ;;
    test)
        test_registry
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        print_error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac