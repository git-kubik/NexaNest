#!/bin/bash

# Setup Remote Docker Access for NexaNest
# Configures TLS certificates and remote Docker daemon access

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DOCKER_HOST_IP="${DOCKER_HOST_IP:-}"
DOCKER_HOST_USER="${DOCKER_HOST_USER:-ubuntu}"
DOCKER_PORT="${DOCKER_PORT:-2376}"
CERT_DIR="${CERT_DIR:-~/.docker/nexanest}"
DOCKER_DAEMON_CONFIG="/etc/docker/daemon.json"

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

# Function to show usage
show_usage() {
    echo "Setup Remote Docker Access for NexaNest"
    echo ""
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  generate-certs    Generate TLS certificates for Docker daemon"
    echo "  configure-daemon  Configure Docker daemon for remote access"
    echo "  setup-client      Set up client certificates and configuration"
    echo "  test-connection   Test remote Docker connection"
    echo "  deploy-registry   Deploy registry to remote Docker host"
    echo "  help              Show this help message"
    echo ""
    echo "Options:"
    echo "  --host IP         Docker host IP address (required)"
    echo "  --user USER       SSH user for Docker host (default: ubuntu)"
    echo "  --port PORT       Docker daemon port (default: 2376)"
    echo "  --cert-dir DIR    Certificate directory (default: ~/.docker/nexanest)"
    echo ""
    echo "Environment Variables:"
    echo "  DOCKER_HOST_IP    Docker host IP address"
    echo "  DOCKER_HOST_USER  SSH user for Docker host"
    echo "  DOCKER_PORT       Docker daemon port"
    echo "  CERT_DIR          Certificate directory"
    echo ""
    echo "Examples:"
    echo "  $0 generate-certs --host 192.168.1.100"
    echo "  $0 configure-daemon --host 192.168.1.100 --user ubuntu"
    echo "  $0 setup-client"
    echo "  $0 test-connection"
}

# Function to validate requirements
validate_requirements() {
    if [ -z "$DOCKER_HOST_IP" ]; then
        print_error "Docker host IP address is required"
        echo "Set DOCKER_HOST_IP environment variable or use --host option"
        exit 1
    fi
    
    # Check if openssl is available
    if ! command -v openssl &> /dev/null; then
        print_error "OpenSSL is required but not installed"
        exit 1
    fi
    
    # Check if ssh is available
    if ! command -v ssh &> /dev/null; then
        print_error "SSH is required but not installed"
        exit 1
    fi
}

# Function to generate TLS certificates
generate_certs() {
    print_status "Generating TLS certificates for Docker daemon..."
    
    # Create certificate directory
    mkdir -p "$CERT_DIR"
    cd "$CERT_DIR"
    
    print_status "Creating CA private key..."
    openssl genrsa -aes256 -out ca-key.pem 4096 2>/dev/null || {
        print_error "Failed to generate CA private key"
        exit 1
    }
    
    print_status "Creating CA certificate..."
    openssl req -new -x509 -days 365 -key ca-key.pem -sha256 -out ca.pem -subj "/C=AU/ST=SA/L=Adelaide/O=NexaNest/CN=nexanest-ca" 2>/dev/null || {
        print_error "Failed to generate CA certificate"
        exit 1
    }
    
    print_status "Creating server private key..."
    openssl genrsa -out server-key.pem 4096 2>/dev/null || {
        print_error "Failed to generate server private key"
        exit 1
    }
    
    print_status "Creating server certificate signing request..."
    openssl req -subj "/C=AU/ST=SA/L=Adelaide/O=NexaNest/CN=nexanest-docker" -sha256 -new -key server-key.pem -out server.csr 2>/dev/null || {
        print_error "Failed to generate server CSR"
        exit 1
    }
    
    print_status "Creating server certificate extensions..."
    cat > server-extfile.cnf << EOF
subjectAltName = DNS:${DOCKER_HOST_IP},IP:${DOCKER_HOST_IP},IP:127.0.0.1,DNS:localhost
extendedKeyUsage = serverAuth
EOF
    
    print_status "Signing server certificate..."
    openssl x509 -req -days 365 -sha256 -in server.csr -CA ca.pem -CAkey ca-key.pem -out server-cert.pem -extfile server-extfile.cnf -CAcreateserial 2>/dev/null || {
        print_error "Failed to sign server certificate"
        exit 1
    }
    
    print_status "Creating client private key..."
    openssl genrsa -out key.pem 4096 2>/dev/null || {
        print_error "Failed to generate client private key"
        exit 1
    }
    
    print_status "Creating client certificate signing request..."
    openssl req -subj "/C=AU/ST=SA/L=Adelaide/O=NexaNest/CN=nexanest-client" -new -key key.pem -out client.csr 2>/dev/null || {
        print_error "Failed to generate client CSR"
        exit 1
    }
    
    print_status "Creating client certificate extensions..."
    cat > client-extfile.cnf << EOF
extendedKeyUsage = clientAuth
EOF
    
    print_status "Signing client certificate..."
    openssl x509 -req -days 365 -sha256 -in client.csr -CA ca.pem -CAkey ca-key.pem -out cert.pem -extfile client-extfile.cnf -CAcreateserial 2>/dev/null || {
        print_error "Failed to sign client certificate"
        exit 1
    }
    
    # Clean up
    rm -f server.csr client.csr server-extfile.cnf client-extfile.cnf
    
    # Set proper permissions
    chmod 400 ca-key.pem key.pem server-key.pem
    chmod 444 ca.pem server-cert.pem cert.pem
    
    print_success "TLS certificates generated successfully in $CERT_DIR"
    
    # List generated files
    print_status "Generated files:"
    ls -la "$CERT_DIR"
}

# Function to configure Docker daemon on remote host
configure_daemon() {
    print_status "Configuring Docker daemon on remote host ${DOCKER_HOST_IP}..."
    
    if [ ! -f "$CERT_DIR/server-key.pem" ]; then
        print_error "Server certificates not found. Run 'generate-certs' first."
        exit 1
    fi
    
    print_status "Copying certificates to remote host..."
    ssh "$DOCKER_HOST_USER@$DOCKER_HOST_IP" "sudo mkdir -p /etc/docker/certs" || {
        print_error "Failed to create certificate directory on remote host"
        exit 1
    }
    
    scp "$CERT_DIR/ca.pem" "$CERT_DIR/server-cert.pem" "$CERT_DIR/server-key.pem" \
        "$DOCKER_HOST_USER@$DOCKER_HOST_IP:/tmp/" || {
        print_error "Failed to copy certificates to remote host"
        exit 1
    }
    
    ssh "$DOCKER_HOST_USER@$DOCKER_HOST_IP" "
        sudo mv /tmp/ca.pem /tmp/server-cert.pem /tmp/server-key.pem /etc/docker/certs/
        sudo chmod 400 /etc/docker/certs/server-key.pem
        sudo chmod 444 /etc/docker/certs/ca.pem /etc/docker/certs/server-cert.pem
        sudo chown root:root /etc/docker/certs/*
    " || {
        print_error "Failed to install certificates on remote host"
        exit 1
    }
    
    print_status "Creating Docker daemon configuration..."
    ssh "$DOCKER_HOST_USER@$DOCKER_HOST_IP" "
        sudo tee $DOCKER_DAEMON_CONFIG > /dev/null << 'EOF'
{
  \"hosts\": [\"unix:///var/run/docker.sock\", \"tcp://0.0.0.0:$DOCKER_PORT\"],
  \"tls\": true,
  \"tlscert\": \"/etc/docker/certs/server-cert.pem\",
  \"tlskey\": \"/etc/docker/certs/server-key.pem\",
  \"tlsverify\": true,
  \"tlscacert\": \"/etc/docker/certs/ca.pem\",
  \"insecure-registries\": [\"localhost:5000\", \"${DOCKER_HOST_IP}:5000\"],
  \"log-driver\": \"json-file\",
  \"log-opts\": {
    \"max-size\": \"10m\",
    \"max-file\": \"3\"
  }
}
EOF
    " || {
        print_error "Failed to create Docker daemon configuration"
        exit 1
    }
    
    print_status "Creating Docker systemd override..."
    ssh "$DOCKER_HOST_USER@$DOCKER_HOST_IP" "
        sudo mkdir -p /etc/systemd/system/docker.service.d
        sudo tee /etc/systemd/system/docker.service.d/override.conf > /dev/null << 'EOF'
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd
EOF
    " || {
        print_error "Failed to create systemd override"
        exit 1
    }
    
    print_status "Restarting Docker daemon..."
    ssh "$DOCKER_HOST_USER@$DOCKER_HOST_IP" "
        sudo systemctl daemon-reload
        sudo systemctl restart docker
        sudo systemctl enable docker
    " || {
        print_error "Failed to restart Docker daemon"
        exit 1
    }
    
    print_status "Waiting for Docker daemon to start..."
    sleep 5
    
    # Verify Docker daemon is running
    if ssh "$DOCKER_HOST_USER@$DOCKER_HOST_IP" "sudo systemctl is-active docker" | grep -q "active"; then
        print_success "Docker daemon configured and running successfully"
    else
        print_error "Docker daemon failed to start"
        exit 1
    fi
}

# Function to set up client configuration
setup_client() {
    print_status "Setting up Docker client configuration..."
    
    if [ ! -f "$CERT_DIR/cert.pem" ]; then
        print_error "Client certificates not found. Run 'generate-certs' first."
        exit 1
    fi
    
    # Create Docker client configuration
    print_status "Creating Docker client configuration..."
    cat > "$CERT_DIR/docker-config.sh" << EOF
#!/bin/bash
# Docker remote access configuration for NexaNest

export DOCKER_HOST="tcp://${DOCKER_HOST_IP}:${DOCKER_PORT}"
export DOCKER_TLS_VERIFY=1
export DOCKER_CERT_PATH="$CERT_DIR"

echo "Docker configured for remote access:"
echo "  Host: \$DOCKER_HOST"
echo "  TLS: \$DOCKER_TLS_VERIFY"
echo "  Certs: \$DOCKER_CERT_PATH"
EOF
    
    chmod +x "$CERT_DIR/docker-config.sh"
    
    # Create convenient aliases
    cat > "$CERT_DIR/docker-aliases.sh" << EOF
#!/bin/bash
# Docker aliases for NexaNest remote access

alias docker-nexanest="DOCKER_HOST=tcp://${DOCKER_HOST_IP}:${DOCKER_PORT} DOCKER_TLS_VERIFY=1 DOCKER_CERT_PATH=$CERT_DIR docker"
alias docker-compose-nexanest="DOCKER_HOST=tcp://${DOCKER_HOST_IP}:${DOCKER_PORT} DOCKER_TLS_VERIFY=1 DOCKER_CERT_PATH=$CERT_DIR docker-compose"

# Registry management with remote Docker
alias registry-nexanest="DOCKER_HOST=tcp://${DOCKER_HOST_IP}:${DOCKER_PORT} DOCKER_TLS_VERIFY=1 DOCKER_CERT_PATH=$CERT_DIR ./scripts/registry-manage.sh"
alias build-nexanest="DOCKER_HOST=tcp://${DOCKER_HOST_IP}:${DOCKER_PORT} DOCKER_TLS_VERIFY=1 DOCKER_CERT_PATH=$CERT_DIR ./scripts/build-and-push.sh"

echo "Docker aliases created:"
echo "  docker-nexanest         - Remote Docker commands"
echo "  docker-compose-nexanest - Remote Docker Compose"
echo "  registry-nexanest       - Remote registry management"
echo "  build-nexanest          - Remote build and push"
EOF
    
    chmod +x "$CERT_DIR/docker-aliases.sh"
    
    print_success "Client configuration created in $CERT_DIR"
    print_status "To use remote Docker, source the configuration:"
    echo "  source $CERT_DIR/docker-config.sh"
    echo "  source $CERT_DIR/docker-aliases.sh"
}

# Function to test connection
test_connection() {
    print_status "Testing remote Docker connection..."
    
    if [ ! -f "$CERT_DIR/cert.pem" ]; then
        print_error "Client certificates not found. Run 'setup-client' first."
        exit 1
    fi
    
    # Set environment variables
    export DOCKER_HOST="tcp://${DOCKER_HOST_IP}:${DOCKER_PORT}"
    export DOCKER_TLS_VERIFY=1
    export DOCKER_CERT_PATH="$CERT_DIR"
    
    print_status "Testing basic Docker connection..."
    if docker version > /dev/null 2>&1; then
        print_success "✓ Docker connection successful"
        
        print_status "Docker version information:"
        docker version --format "Client: {{.Client.Version}}, Server: {{.Server.Version}}"
        
        print_status "Testing Docker info..."
        if docker info --format "Swarm: {{.Swarm.LocalNodeState}}" > /dev/null 2>&1; then
            print_success "✓ Docker info accessible"
            
            # Show swarm status
            SWARM_STATUS=$(docker info --format "{{.Swarm.LocalNodeState}}")
            print_status "Swarm status: $SWARM_STATUS"
            
        else
            print_warning "Docker info not accessible"
        fi
    else
        print_error "✗ Docker connection failed"
        print_status "Check Docker daemon configuration and firewall settings"
        exit 1
    fi
}

# Function to deploy registry to remote host
deploy_registry() {
    print_status "Deploying Docker registry to remote host..."
    
    # Test connection first
    test_connection
    
    print_status "Deploying registry container..."
    
    # Set environment variables for remote Docker
    export DOCKER_HOST="tcp://${DOCKER_HOST_IP}:${DOCKER_PORT}"
    export DOCKER_TLS_VERIFY=1
    export DOCKER_CERT_PATH="$CERT_DIR"
    
    # Update REGISTRY_URL for remote host
    export REGISTRY_URL="${DOCKER_HOST_IP}:5000"
    
    # Use the existing registry management script
    ./scripts/registry-manage.sh start
    
    print_success "Registry deployed to remote host"
    print_status "Registry URL: ${REGISTRY_URL}"
}

# Parse command line arguments
COMMAND=""
while [[ $# -gt 0 ]]; do
    case $1 in
        generate-certs|configure-daemon|setup-client|test-connection|deploy-registry|help)
            COMMAND="$1"
            shift
            ;;
        --host)
            DOCKER_HOST_IP="$2"
            shift 2
            ;;
        --user)
            DOCKER_HOST_USER="$2"
            shift 2
            ;;
        --port)
            DOCKER_PORT="$2"
            shift 2
            ;;
        --cert-dir)
            CERT_DIR="$2"
            shift 2
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Main execution
case "$COMMAND" in
    generate-certs)
        validate_requirements
        generate_certs
        ;;
    configure-daemon)
        validate_requirements
        configure_daemon
        ;;
    setup-client)
        validate_requirements
        setup_client
        ;;
    test-connection)
        validate_requirements
        test_connection
        ;;
    deploy-registry)
        validate_requirements
        deploy_registry
        ;;
    help|"")
        show_usage
        ;;
    *)
        print_error "Unknown command: $COMMAND"
        show_usage
        exit 1
        ;;
esac