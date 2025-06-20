#!/bin/bash

# Setup SSH Access for pgdb.nn.local
# Configures SSH key-based authentication for database host access

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
SSH_HOST="pgdb.nn.local"
SSH_USER="m"
SSH_KEY="/home/m/.ssh/id_ed25519_makka_ubuntu_sso"
SSH_CONFIG_FILE="$HOME/.ssh/config"

# Functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_ssh_key() {
    log_info "Checking SSH key..."
    
    if [[ ! -f "$SSH_KEY" ]]; then
        log_error "SSH key not found: $SSH_KEY"
        log_error "Please ensure the key exists or update the path in this script"
        exit 1
    fi
    
    # Check key permissions
    local key_perms=$(stat -c "%a" "$SSH_KEY")
    if [[ "$key_perms" != "600" ]]; then
        log_warn "SSH key permissions are $key_perms, should be 600"
        log_info "Fixing SSH key permissions..."
        chmod 600 "$SSH_KEY"
    fi
    
    log_info "SSH key found and permissions are correct"
}

test_ssh_connection() {
    log_info "Testing SSH connection to $SSH_USER@$SSH_HOST..."
    
    if ssh -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new "$SSH_USER@$SSH_HOST" "echo 'SSH connection successful'" &>/dev/null; then
        log_info "SSH connection successful"
        return 0
    else
        log_error "SSH connection failed"
        return 1
    fi
}

test_docker_access() {
    log_info "Testing Docker access via sudo..."
    
    if ssh -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new "$SSH_USER@$SSH_HOST" "sudo docker version" &>/dev/null; then
        log_info "Docker access via sudo successful"
        return 0
    else
        log_error "Docker access via sudo failed"
        log_error "User '$SSH_USER' may not have sudo access to docker commands"
        return 1
    fi
}

setup_ssh_config() {
    log_info "Setting up SSH config for pgdb.nn.local..."
    
    # Create SSH config entry
    local ssh_config_entry="
# NexaNest Database Host
Host pgdb.nn.local
    HostName pgdb.nn.local
    User $SSH_USER
    IdentityFile $SSH_KEY
    IdentitiesOnly yes
    StrictHostKeyChecking accept-new
    ServerAliveInterval 60
    ServerAliveCountMax 3
"
    
    # Check if entry already exists
    if grep -q "Host pgdb.nn.local" "$SSH_CONFIG_FILE" 2>/dev/null; then
        log_warn "SSH config entry for pgdb.nn.local already exists"
        log_info "You may want to verify the configuration manually"
    else
        log_info "Adding SSH config entry..."
        echo "$ssh_config_entry" >> "$SSH_CONFIG_FILE"
        log_info "SSH config entry added"
    fi
}

show_connection_info() {
    log_info "SSH Connection Information:"
    echo ""
    echo "Host: $SSH_HOST"
    echo "User: $SSH_USER"
    echo "Key:  $SSH_KEY"
    echo ""
    echo "Test connection:"
    echo "  ssh $SSH_USER@$SSH_HOST"
    echo ""
    echo "Test Docker access:"
    echo "  ssh $SSH_USER@$SSH_HOST 'sudo docker version'"
    echo ""
    echo "Deploy databases:"
    echo "  ./scripts/deploy-database.sh deploy"
}

show_troubleshooting() {
    log_error "SSH connection troubleshooting:"
    echo ""
    echo "1. Verify SSH key exists and has correct permissions:"
    echo "   ls -la $SSH_KEY"
    echo "   chmod 600 $SSH_KEY"
    echo ""
    echo "2. Test SSH connection manually:"
    echo "   ssh -i $SSH_KEY -v $SSH_USER@$SSH_HOST"
    echo ""
    echo "3. Verify host is reachable:"
    echo "   ping $SSH_HOST"
    echo ""
    echo "4. Check if user has sudo access to docker:"
    echo "   ssh -i $SSH_KEY $SSH_USER@$SSH_HOST 'sudo docker version'"
    echo ""
    echo "5. If sudo requires password, you may need to configure passwordless sudo for docker commands"
}

# Main execution
case "${1:-setup}" in
    "setup")
        log_info "Setting up SSH access for NexaNest database host..."
        
        check_ssh_key
        
        if test_ssh_connection; then
            if test_docker_access; then
                setup_ssh_config
                show_connection_info
                log_info "SSH access setup completed successfully!"
            else
                show_troubleshooting
                exit 1
            fi
        else
            show_troubleshooting
            exit 1
        fi
        ;;
    "test")
        check_ssh_key
        if test_ssh_connection && test_docker_access; then
            log_info "All SSH and Docker access tests passed!"
            show_connection_info
        else
            show_troubleshooting
            exit 1
        fi
        ;;
    "troubleshoot")
        show_troubleshooting
        ;;
    "help")
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  setup         Setup SSH access (default)"
        echo "  test          Test SSH and Docker access"
        echo "  troubleshoot  Show troubleshooting information"
        echo "  help          Show this help"
        echo ""
        echo "This script configures SSH access to pgdb.nn.local for database deployment."
        ;;
    *)
        log_error "Unknown command: $1"
        echo "Use '$0 help' for usage information"
        exit 1
        ;;
esac