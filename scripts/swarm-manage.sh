#!/bin/bash
# =============================================================================
# Docker Swarm Management Script
# =============================================================================
# This script manages Docker Swarm cluster operations using environment variables
# for SSH access and cluster configuration
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
            # Export variables from .env file
            set -a
            source "$env_file"
            set +a
        else
            print_warning "Environment file not found: $env_file"
        fi
    done
}

# Function to validate required environment variables
validate_env_vars() {
    local required_vars=(
        "SWARM_MANAGER_HOST"
        "SWARM_MANAGER_USER"
        "SWARM_MANAGER_SSH_KEY_PATH"
    )
    
    local missing_vars=()
    
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            missing_vars+=("$var")
        fi
    done
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        print_error "Missing required environment variables:"
        for var in "${missing_vars[@]}"; do
            echo "  - $var"
        done
        print_info "Please configure these variables in .env.swarm file"
        exit 1
    fi
}

# Function to test SSH connectivity
test_ssh_connection() {
    local host="$1"
    local user="$2"
    local key_path="$3"
    local port="${4:-22}"
    
    print_info "Testing SSH connection to $user@$host:$port"
    
    if ssh -i "$key_path" -p "$port" -o ConnectTimeout=10 -o BatchMode=yes \
       "$user@$host" "echo 'SSH connection successful'" >/dev/null 2>&1; then
        print_success "SSH connection to $host successful"
        return 0
    else
        print_error "SSH connection to $host failed"
        return 1
    fi
}

# Function to execute command on remote host via SSH
ssh_exec() {
    local host="$1"
    local user="$2"
    local key_path="$3"
    local command="$4"
    local port="${5:-22}"
    
    ssh -i "$key_path" -p "$port" -o ConnectTimeout=30 \
        "$user@$host" "$command"
}

# Function to copy file to remote host
ssh_copy() {
    local host="$1"
    local user="$2"
    local key_path="$3"
    local local_file="$4"
    local remote_file="$5"
    local port="${6:-22}"
    
    scp -i "$key_path" -P "$port" "$local_file" "$user@$host:$remote_file"
}

# Function to check if Docker is installed on a node
check_docker_installation() {
    local host="$1"
    local user="$2"
    local key_path="$3"
    
    print_info "Checking Docker installation on $host"
    
    if ssh_exec "$host" "$user" "$key_path" "docker --version" >/dev/null 2>&1; then
        local docker_version=$(ssh_exec "$host" "$user" "$key_path" "docker --version")
        print_success "Docker found on $host: $docker_version"
        return 0
    else
        print_warning "Docker not found on $host"
        return 1
    fi
}

# Function to install Docker on a node
install_docker() {
    local host="$1"
    local user="$2"
    local key_path="$3"
    
    print_info "Installing Docker on $host"
    
    # Docker installation script
    local install_script="
        # Update package index
        sudo apt-get update
        
        # Install prerequisites
        sudo apt-get install -y ca-certificates curl gnupg lsb-release
        
        # Add Docker GPG key
        sudo mkdir -p /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        
        # Add Docker repository
        echo \"deb [arch=\$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \$(lsb_release -cs) stable\" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        # Install Docker
        sudo apt-get update
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        
        # Add user to docker group
        sudo usermod -aG docker $user
        
        # Start and enable Docker
        sudo systemctl start docker
        sudo systemctl enable docker
        
        # Test Docker installation
        sudo docker run hello-world
    "
    
    ssh_exec "$host" "$user" "$key_path" "$install_script"
    print_success "Docker installed on $host"
}

# Function to initialize Docker Swarm
init_swarm() {
    print_info "Initializing Docker Swarm on manager node"
    
    local manager_host="$SWARM_MANAGER_HOST"
    local manager_user="$SWARM_MANAGER_USER"
    local manager_key="$SWARM_MANAGER_SSH_KEY_PATH"
    local advertise_addr="${SWARM_ADVERTISE_ADDR:-$manager_host}"
    local listen_addr="${SWARM_LISTEN_ADDR:-0.0.0.0:2377}"
    
    # Check if swarm is already initialized
    if ssh_exec "$manager_host" "$manager_user" "$manager_key" \
       "docker info --format '{{.Swarm.LocalNodeState}}'" | grep -q "active"; then
        print_warning "Swarm already initialized on $manager_host"
        return 0
    fi
    
    # Initialize swarm
    local init_output=$(ssh_exec "$manager_host" "$manager_user" "$manager_key" \
        "docker swarm init --advertise-addr $advertise_addr --listen-addr $listen_addr")
    
    print_success "Swarm initialized on $manager_host"
    echo "$init_output"
    
    # Extract join tokens
    local manager_token=$(ssh_exec "$manager_host" "$manager_user" "$manager_key" \
        "docker swarm join-token manager -q")
    local worker_token=$(ssh_exec "$manager_host" "$manager_user" "$manager_key" \
        "docker swarm join-token worker -q")
    
    print_info "Manager join token: $manager_token"
    print_info "Worker join token: $worker_token"
    
    # Save tokens to environment file (optional)
    if [[ -f "$PROJECT_ROOT/.env.swarm" ]]; then
        sed -i.bak "s/SWARM_MANAGER_TOKEN=.*/SWARM_MANAGER_TOKEN=$manager_token/" "$PROJECT_ROOT/.env.swarm"
        sed -i.bak "s/SWARM_WORKER_TOKEN=.*/SWARM_WORKER_TOKEN=$worker_token/" "$PROJECT_ROOT/.env.swarm"
        print_success "Tokens saved to .env.swarm"
    fi
}

# Function to join worker nodes to swarm
join_workers() {
    print_info "Joining worker nodes to swarm"
    
    local manager_host="$SWARM_MANAGER_HOST"
    local manager_user="$SWARM_MANAGER_USER"
    local manager_key="$SWARM_MANAGER_SSH_KEY_PATH"
    
    # Get worker token if not set
    if [[ -z "${SWARM_WORKER_TOKEN:-}" ]]; then
        SWARM_WORKER_TOKEN=$(ssh_exec "$manager_host" "$manager_user" "$manager_key" \
            "docker swarm join-token worker -q")
    fi
    
    # Join worker nodes
    local worker_vars=($(env | grep "SWARM_WORKER_.*_HOST=" | cut -d= -f1))
    
    for worker_var in "${worker_vars[@]}"; do
        local worker_num=$(echo "$worker_var" | sed 's/SWARM_WORKER_//; s/_HOST//')
        local worker_host_var="SWARM_WORKER_${worker_num}_HOST"
        local worker_user_var="SWARM_WORKER_${worker_num}_USER"
        local worker_key_var="SWARM_WORKER_${worker_num}_SSH_KEY_PATH"
        
        local worker_host="${!worker_host_var}"
        local worker_user="${!worker_user_var:-$SWARM_MANAGER_USER}"
        local worker_key="${!worker_key_var:-$SWARM_MANAGER_SSH_KEY_PATH}"
        
        if [[ -n "$worker_host" ]]; then
            print_info "Joining worker $worker_host to swarm"
            
            # Check if already joined
            if ssh_exec "$worker_host" "$worker_user" "$worker_key" \
               "docker info --format '{{.Swarm.LocalNodeState}}'" | grep -q "active"; then
                print_warning "Worker $worker_host already joined to swarm"
                continue
            fi
            
            # Join worker to swarm
            ssh_exec "$worker_host" "$worker_user" "$worker_key" \
                "docker swarm join --token $SWARM_WORKER_TOKEN $manager_host:2377"
            
            print_success "Worker $worker_host joined to swarm"
        fi
    done
}

# Function to check swarm status
check_swarm_status() {
    print_info "Checking swarm status"
    
    local manager_host="$SWARM_MANAGER_HOST"
    local manager_user="$SWARM_MANAGER_USER"
    local manager_key="$SWARM_MANAGER_SSH_KEY_PATH"
    
    print_info "Swarm nodes:"
    ssh_exec "$manager_host" "$manager_user" "$manager_key" "docker node ls"
    
    print_info "Swarm services:"
    ssh_exec "$manager_host" "$manager_user" "$manager_key" "docker service ls"
    
    print_info "Swarm networks:"
    ssh_exec "$manager_host" "$manager_user" "$manager_key" "docker network ls --filter driver=overlay"
}

# Function to create overlay network
create_overlay_network() {
    local network_name="${SWARM_OVERLAY_NETWORK:-nexanest-overlay}"
    local subnet="${SWARM_OVERLAY_SUBNET:-10.1.0.0/24}"
    
    print_info "Creating overlay network: $network_name"
    
    local manager_host="$SWARM_MANAGER_HOST"
    local manager_user="$SWARM_MANAGER_USER"
    local manager_key="$SWARM_MANAGER_SSH_KEY_PATH"
    
    # Check if network already exists
    if ssh_exec "$manager_host" "$manager_user" "$manager_key" \
       "docker network ls --format '{{.Name}}'" | grep -q "^$network_name$"; then
        print_warning "Network $network_name already exists"
        return 0
    fi
    
    # Create overlay network
    ssh_exec "$manager_host" "$manager_user" "$manager_key" \
        "docker network create --driver overlay --subnet $subnet --attachable $network_name"
    
    print_success "Overlay network $network_name created"
}

# Function to deploy stack
deploy_stack() {
    local stack_name="${1:-nexanest}"
    local compose_file="${2:-infrastructure/docker/docker-compose.swarm.yml}"
    
    print_info "Deploying stack: $stack_name"
    
    local manager_host="$SWARM_MANAGER_HOST"
    local manager_user="$SWARM_MANAGER_USER"
    local manager_key="$SWARM_MANAGER_SSH_KEY_PATH"
    
    # Copy compose file to manager node
    local remote_compose_file="/tmp/docker-compose-$stack_name.yml"
    ssh_copy "$manager_host" "$manager_user" "$manager_key" \
        "$PROJECT_ROOT/$compose_file" "$remote_compose_file"
    
    # Deploy stack
    ssh_exec "$manager_host" "$manager_user" "$manager_key" \
        "docker stack deploy -c $remote_compose_file $stack_name"
    
    print_success "Stack $stack_name deployed"
}

# Function to show usage
show_usage() {
    echo "Docker Swarm Management Script"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  test-connection    Test SSH connectivity to all nodes"
    echo "  install-docker     Install Docker on all nodes"
    echo "  init               Initialize Docker Swarm cluster"
    echo "  join-workers       Join worker nodes to swarm"
    echo "  status             Show swarm cluster status"
    echo "  create-network     Create overlay network"
    echo "  deploy [stack]     Deploy stack to swarm"
    echo "  setup              Complete cluster setup (install + init + join)"
    echo "  help               Show this help message"
    echo ""
    echo "Environment files:"
    echo "  .env.swarm         Swarm-specific configuration"
    echo "  .env               General environment variables"
}

# Main script logic
main() {
    local command="${1:-help}"
    
    # Load environment variables
    load_env_files
    
    case "$command" in
        "test-connection")
            validate_env_vars
            test_ssh_connection "$SWARM_MANAGER_HOST" "$SWARM_MANAGER_USER" "$SWARM_MANAGER_SSH_KEY_PATH"
            ;;
        "install-docker")
            validate_env_vars
            if ! check_docker_installation "$SWARM_MANAGER_HOST" "$SWARM_MANAGER_USER" "$SWARM_MANAGER_SSH_KEY_PATH"; then
                install_docker "$SWARM_MANAGER_HOST" "$SWARM_MANAGER_USER" "$SWARM_MANAGER_SSH_KEY_PATH"
            fi
            ;;
        "init")
            validate_env_vars
            init_swarm
            ;;
        "join-workers")
            validate_env_vars
            join_workers
            ;;
        "status")
            validate_env_vars
            check_swarm_status
            ;;
        "create-network")
            validate_env_vars
            create_overlay_network
            ;;
        "deploy")
            validate_env_vars
            deploy_stack "${2:-nexanest}" "${3:-infrastructure/docker/docker-compose.swarm.yml}"
            ;;
        "setup")
            validate_env_vars
            print_info "Starting complete swarm setup..."
            test_ssh_connection "$SWARM_MANAGER_HOST" "$SWARM_MANAGER_USER" "$SWARM_MANAGER_SSH_KEY_PATH"
            if ! check_docker_installation "$SWARM_MANAGER_HOST" "$SWARM_MANAGER_USER" "$SWARM_MANAGER_SSH_KEY_PATH"; then
                install_docker "$SWARM_MANAGER_HOST" "$SWARM_MANAGER_USER" "$SWARM_MANAGER_SSH_KEY_PATH"
            fi
            init_swarm
            join_workers
            create_overlay_network
            check_swarm_status
            print_success "Swarm setup complete!"
            ;;
        "help"|*)
            show_usage
            ;;
    esac
}

# Run main function with all arguments
main "$@"