#!/bin/bash
# =============================================================================
# Docker Registry Configuration Script
# =============================================================================
# This script configures Docker clients to connect to the NexaNest registry
# =============================================================================

set -euo pipefail

# Script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Function to load environment variables
load_env_files() {
    local env_files=(
        "$PROJECT_ROOT/.env"
        "$PROJECT_ROOT/.env.swarm"
    )
    
    for env_file in "${env_files[@]}"; do
        if [[ -f "$env_file" ]]; then
            print_info "Loading environment from $env_file"
            set -a
            source "$env_file"
            set +a
        fi
    done
}

# Function to get registry URL
get_registry_url() {
    local registry_host="${SWARM_REGISTRY_HOST:-${DOCKER_REGISTRY%%:*}}"
    local registry_port="${SWARM_REGISTRY_PORT:-${DOCKER_REGISTRY##*:}}"
    
    if [[ -n "${DOCKER_REGISTRY:-}" ]]; then
        echo "$DOCKER_REGISTRY"
    elif [[ -n "$registry_host" && -n "$registry_port" ]]; then
        echo "$registry_host:$registry_port"
    else
        echo "10.9.8.121:5000"  # Default fallback
    fi
}

# Function to test registry connectivity
test_registry_connection() {
    local registry_url="$1"
    
    print_info "Testing connection to registry: $registry_url"
    
    # Test basic connectivity
    if curl -f -s --connect-timeout 10 "http://$registry_url/v2/" >/dev/null; then
        print_success "Registry is accessible at http://$registry_url"
        
        # Test catalog endpoint
        if curl -f -s "http://$registry_url/v2/_catalog" >/dev/null; then
            print_success "Registry API is responding"
            local catalog=$(curl -s "http://$registry_url/v2/_catalog")
            print_info "Registry catalog: $catalog"
        else
            print_warning "Registry accessible but catalog endpoint failed"
        fi
        return 0
    else
        print_error "Cannot connect to registry at $registry_url"
        return 1
    fi
}

# Function to configure Docker daemon for insecure registry
configure_insecure_registry() {
    local registry_url="$1"
    local daemon_config="/etc/docker/daemon.json"
    
    print_info "Configuring Docker daemon for insecure registry: $registry_url"
    
    # Backup existing daemon.json if it exists
    if [[ -f "$daemon_config" ]]; then
        sudo cp "$daemon_config" "$daemon_config.backup.$(date +%Y%m%d-%H%M%S)"
        print_info "Backed up existing daemon.json"
    fi
    
    # Create or update daemon.json
    if [[ -f "$daemon_config" ]]; then
        # Update existing configuration
        local temp_config=$(mktemp)
        jq --arg registry "$registry_url" '
            if has("insecure-registries") then
                ."insecure-registries" |= (. + [$registry] | unique)
            else
                . + {"insecure-registries": [$registry]}
            end
        ' "$daemon_config" > "$temp_config"
        sudo mv "$temp_config" "$daemon_config"
    else
        # Create new configuration
        echo "{
  \"insecure-registries\": [\"$registry_url\"]
}" | sudo tee "$daemon_config" >/dev/null
    fi
    
    print_success "Docker daemon configuration updated"
    print_warning "Docker daemon restart required: sudo systemctl restart docker"
}

# Function to restart Docker daemon
restart_docker_daemon() {
    print_info "Restarting Docker daemon..."
    
    if sudo systemctl restart docker; then
        print_success "Docker daemon restarted successfully"
        
        # Wait for Docker to be ready
        local retries=10
        while [[ $retries -gt 0 ]]; do
            if docker info >/dev/null 2>&1; then
                print_success "Docker daemon is ready"
                return 0
            fi
            print_info "Waiting for Docker daemon to be ready... ($retries retries left)"
            sleep 2
            ((retries--))
        done
        
        print_error "Docker daemon not ready after restart"
        return 1
    else
        print_error "Failed to restart Docker daemon"
        return 1
    fi
}

# Function to test Docker registry operations
test_docker_operations() {
    local registry_url="$1"
    
    print_info "Testing Docker operations with registry: $registry_url"
    
    # Pull a test image
    print_info "Pulling hello-world image..."
    if docker pull hello-world; then
        print_success "Successfully pulled hello-world"
    else
        print_error "Failed to pull hello-world"
        return 1
    fi
    
    # Tag and push to registry
    local test_image="$registry_url/nexanest/hello-world:test"
    print_info "Tagging image: $test_image"
    docker tag hello-world "$test_image"
    
    print_info "Pushing image to registry..."
    if docker push "$test_image"; then
        print_success "Successfully pushed test image to registry"
    else
        print_error "Failed to push test image to registry"
        return 1
    fi
    
    # Clean up local test image
    docker rmi "$test_image" hello-world 2>/dev/null || true
    
    print_success "Registry operations test completed successfully"
}

# Function to authenticate with registry
registry_login() {
    local registry_url="$1"
    local username="${SWARM_REGISTRY_USERNAME:-}"
    local password="${SWARM_REGISTRY_PASSWORD:-}"
    
    if [[ -n "$username" && -n "$password" ]]; then
        print_info "Logging in to registry with username: $username"
        echo "$password" | docker login --username "$username" --password-stdin "$registry_url"
        print_success "Successfully logged in to registry"
    else
        print_info "No registry credentials provided, assuming no authentication required"
    fi
}

# Function to configure Swarm nodes for registry access
configure_swarm_nodes() {
    local registry_url="$1"
    
    if [[ -z "${SWARM_MANAGER_HOST:-}" ]]; then
        print_warning "No Swarm configuration found, skipping Swarm node configuration"
        return 0
    fi
    
    print_info "Configuring Swarm nodes for registry access..."
    
    # Configure manager node
    local manager_host="$SWARM_MANAGER_HOST"
    local manager_user="$SWARM_MANAGER_USER"
    local manager_key="$SWARM_MANAGER_SSH_KEY_PATH"
    
    if [[ -f "$manager_key" ]]; then
        print_info "Configuring manager node: $manager_host"
        
        # Copy this script to manager node and execute
        scp -i "$manager_key" "$0" "$manager_user@$manager_host:/tmp/configure-registry.sh"
        ssh -i "$manager_key" "$manager_user@$manager_host" \
            "chmod +x /tmp/configure-registry.sh && sudo /tmp/configure-registry.sh configure-node $registry_url"
        
        print_success "Manager node configured"
    else
        print_warning "SSH key not found: $manager_key"
    fi
    
    # Configure worker nodes
    local worker_vars=($(env | grep "SWARM_WORKER_.*_HOST=" | cut -d= -f1))
    
    for worker_var in "${worker_vars[@]}"; do
        local worker_num=$(echo "$worker_var" | sed 's/SWARM_WORKER_//; s/_HOST//')
        local worker_host_var="SWARM_WORKER_${worker_num}_HOST"
        local worker_user_var="SWARM_WORKER_${worker_num}_USER"
        local worker_key_var="SWARM_WORKER_${worker_num}_SSH_KEY_PATH"
        
        local worker_host="${!worker_host_var}"
        local worker_user="${!worker_user_var:-$manager_user}"
        local worker_key="${!worker_key_var:-$manager_key}"
        
        if [[ -n "$worker_host" && -f "$worker_key" ]]; then
            print_info "Configuring worker node: $worker_host"
            
            scp -i "$worker_key" "$0" "$worker_user@$worker_host:/tmp/configure-registry.sh"
            ssh -i "$worker_key" "$worker_user@$worker_host" \
                "chmod +x /tmp/configure-registry.sh && sudo /tmp/configure-registry.sh configure-node $registry_url"
            
            print_success "Worker node $worker_host configured"
        fi
    done
}

# Function to configure a single node (used by remote execution)
configure_node() {
    local registry_url="$1"
    
    print_info "Configuring Docker on this node for registry: $registry_url"
    
    configure_insecure_registry "$registry_url"
    restart_docker_daemon
    
    print_success "Node configuration completed"
}

# Function to show registry information
show_registry_info() {
    local registry_url="$1"
    
    print_info "Registry Information:"
    echo "  URL: http://$registry_url"
    echo "  API: http://$registry_url/v2/"
    echo "  Catalog: http://$registry_url/v2/_catalog"
    echo ""
    
    print_info "Docker Configuration:"
    echo "  Registry configured as insecure: $registry_url"
    echo "  Docker daemon config: /etc/docker/daemon.json"
    echo ""
    
    print_info "Usage Examples:"
    echo "  # Tag and push an image"
    echo "  docker tag myapp:latest $registry_url/nexanest/myapp:latest"
    echo "  docker push $registry_url/nexanest/myapp:latest"
    echo ""
    echo "  # Pull an image"
    echo "  docker pull $registry_url/nexanest/myapp:latest"
}

# Function to show usage
show_usage() {
    echo "Docker Registry Configuration Script"
    echo ""
    echo "Usage: $0 [COMMAND] [REGISTRY_URL]"
    echo ""
    echo "Commands:"
    echo "  test [url]           Test connection to registry"
    echo "  configure [url]      Configure Docker for registry access"
    echo "  configure-node [url] Configure single node (internal use)"
    echo "  configure-swarm [url] Configure all Swarm nodes"
    echo "  login [url]          Login to registry with credentials"
    echo "  test-ops [url]       Test Docker operations (push/pull)"
    echo "  info [url]           Show registry information"
    echo "  setup [url]          Complete setup (configure + test)"
    echo "  help                 Show this help message"
    echo ""
    echo "If no registry URL is provided, uses value from environment variables:"
    echo "  DOCKER_REGISTRY or SWARM_REGISTRY_HOST:SWARM_REGISTRY_PORT"
    echo ""
    echo "Default registry: 10.9.8.121:5000"
}

# Main script logic
main() {
    local command="${1:-help}"
    local registry_url="${2:-}"
    
    # Load environment variables
    load_env_files
    
    # Get registry URL
    if [[ -z "$registry_url" ]]; then
        registry_url=$(get_registry_url)
    fi
    
    case "$command" in
        "test")
            test_registry_connection "$registry_url"
            ;;
        "configure")
            configure_insecure_registry "$registry_url"
            restart_docker_daemon
            ;;
        "configure-node")
            configure_node "$registry_url"
            ;;
        "configure-swarm")
            configure_swarm_nodes "$registry_url"
            ;;
        "login")
            registry_login "$registry_url"
            ;;
        "test-ops")
            test_docker_operations "$registry_url"
            ;;
        "info")
            show_registry_info "$registry_url"
            ;;
        "setup")
            print_info "Setting up Docker registry access for: $registry_url"
            test_registry_connection "$registry_url"
            configure_insecure_registry "$registry_url"
            restart_docker_daemon
            registry_login "$registry_url"
            test_docker_operations "$registry_url"
            show_registry_info "$registry_url"
            print_success "Registry setup completed successfully!"
            ;;
        "help"|*)
            show_usage
            ;;
    esac
}

# Run main function with all arguments
main "$@"