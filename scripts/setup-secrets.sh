#!/bin/bash
# =============================================================================
# NexaNest Secrets Setup Script
# =============================================================================
# This script sets up environment variables and Docker secrets for development
# and production deployments
# =============================================================================

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SECRETS_DIR="$PROJECT_ROOT/infrastructure/secrets"

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

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to generate secure password
generate_password() {
    local length=${1:-32}
    if command_exists openssl; then
        openssl rand -base64 $length | tr -d "=+/" | cut -c1-$length
    elif command_exists uuidgen; then
        uuidgen | tr -d '-' | cut -c1-$length
    else
        print_error "Neither openssl nor uuidgen found. Please install one of them."
        exit 1
    fi
}

# Function to create .env file from template
create_env_file() {
    local env_file="$PROJECT_ROOT/.env"
    local env_example="$PROJECT_ROOT/.env.example"
    
    if [[ -f "$env_file" ]]; then
        print_warning ".env file already exists. Skipping creation."
        return
    fi
    
    if [[ ! -f "$env_example" ]]; then
        print_error ".env.example not found"
        return 1
    fi
    
    print_info "Creating .env file from template..."
    cp "$env_example" "$env_file"
    
    # Generate secure passwords for development
    local postgres_password=$(generate_password)
    local timescale_password=$(generate_password)
    local redis_password=$(generate_password)
    local jwt_secret=$(generate_password 64)
    local secret_key=$(generate_password 64)
    
    # Update .env file with generated passwords
    sed -i.bak "s/your_secure_postgres_password_here/$postgres_password/g" "$env_file"
    sed -i.bak "s/your_secure_timescale_password_here/$timescale_password/g" "$env_file"
    sed -i.bak "s/your_secure_redis_password_here/$redis_password/g" "$env_file"
    sed -i.bak "s/your_jwt_secret_key_minimum_32_characters_long/$jwt_secret/g" "$env_file"
    sed -i.bak "s/your_very_secure_secret_key_minimum_32_characters_long/$secret_key/g" "$env_file"
    
    # Remove backup file
    rm -f "$env_file.bak"
    
    print_success ".env file created with generated passwords"
}

# Function to create database .env file
create_db_env_file() {
    local db_env_file="$PROJECT_ROOT/.env.db"
    local db_env_example="$PROJECT_ROOT/.env.db.example"
    
    if [[ -f "$db_env_file" ]]; then
        print_warning ".env.db file already exists. Skipping creation."
        return
    fi
    
    if [[ ! -f "$db_env_example" ]]; then
        print_error ".env.db.example not found"
        return 1
    fi
    
    print_info "Creating .env.db file from template..."
    cp "$db_env_example" "$db_env_file"
    
    # Generate secure passwords
    local postgres_password=$(generate_password)
    local timescale_password=$(generate_password)
    local redis_password=$(generate_password)
    local pgadmin_password=$(generate_password 24)
    
    # Update .env.db file
    sed -i.bak "s/nexanest_secure_password_change_me/$postgres_password/g" "$db_env_file"
    sed -i.bak "s/timescale_secure_password_change_me/$timescale_password/g" "$db_env_file"
    sed -i.bak "s/redis_secure_password_change_me/$redis_password/g" "$db_env_file"
    sed -i.bak "s/pgadmin_secure_password_change_me/$pgadmin_password/g" "$db_env_file"
    
    # Remove backup file
    rm -f "$db_env_file.bak"
    
    print_success ".env.db file created with generated passwords"
}

# Function to create Docker secrets
create_docker_secrets() {
    print_info "Setting up Docker secrets..."
    
    # Create secrets directory
    mkdir -p "$SECRETS_DIR/secrets"
    
    # Run the secrets generation script
    if [[ -f "$SECRETS_DIR/generate-secrets.sh" ]]; then
        cd "$SECRETS_DIR"
        ./generate-secrets.sh
        print_success "Docker secrets generated"
    else
        print_error "Secrets generation script not found"
        return 1
    fi
}

# Function to update .gitignore
update_gitignore() {
    local gitignore="$PROJECT_ROOT/.gitignore"
    
    print_info "Updating .gitignore..."
    
    # Create .gitignore if it doesn't exist
    if [[ ! -f "$gitignore" ]]; then
        touch "$gitignore"
    fi
    
    # Add environment files and secrets to .gitignore if not already present
    local entries=(
        "# Environment files"
        ".env"
        ".env.local"
        ".env.*.local"
        ".env.db"
        ""
        "# Docker secrets"
        "infrastructure/secrets/secrets/"
        ""
        "# Service-specific environment files"
        "services/*/.env"
        "services/*/.env.local"
    )
    
    for entry in "${entries[@]}"; do
        if ! grep -Fxq "$entry" "$gitignore"; then
            echo "$entry" >> "$gitignore"
        fi
    done
    
    print_success ".gitignore updated"
}

# Function to create service environment files
create_service_env_files() {
    print_info "Creating service-specific environment files..."
    
    local services=("auth" "portfolio" "market-data" "analytics" "notification")
    
    for service in "${services[@]}"; do
        local service_dir="$PROJECT_ROOT/services/$service"
        local env_file="$service_dir/.env"
        local env_example="$service_dir/.env.example"
        
        if [[ ! -d "$service_dir" ]]; then
            print_warning "Service directory $service not found, skipping..."
            continue
        fi
        
        if [[ -f "$env_file" ]]; then
            print_warning "Service $service .env file already exists, skipping..."
            continue
        fi
        
        if [[ -f "$env_example" ]]; then
            print_info "Creating $service service .env file..."
            cp "$env_example" "$env_file"
            print_success "Created $service service .env file"
        else
            print_warning "No .env.example found for $service service"
        fi
    done
}

# Function to show setup summary
show_summary() {
    print_success "Environment setup completed!"
    echo ""
    print_info "Next steps:"
    echo "1. Review and update API keys in .env file"
    echo "2. Update service-specific configurations in services/*/.env"
    echo "3. For production, use Docker secrets with:"
    echo "   docker-compose -f docker-compose.yml -f docker-compose.secrets.yml up"
    echo ""
    print_warning "Security reminders:"
    echo "- Never commit .env files or secrets/ directory to version control"
    echo "- Rotate secrets regularly in production"
    echo "- Use strong, unique passwords for each environment"
    echo "- Enable 2FA for all external service accounts"
}

# Main setup function
main() {
    print_info "Setting up NexaNest environment and secrets management..."
    echo ""
    
    # Create environment files
    create_env_file
    create_db_env_file
    
    # Create service environment files
    create_service_env_files
    
    # Setup Docker secrets
    create_docker_secrets
    
    # Update .gitignore
    update_gitignore
    
    # Show summary
    show_summary
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi