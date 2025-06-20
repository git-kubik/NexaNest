#!/bin/bash

# Deploy Database Script for NexaNest
# Deploys PostgreSQL, TimescaleDB, and Redis to pgdb.nn.local

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
DB_HOST="pgdb.nn.local"
SSH_USER="m"
SSH_KEY="/home/m/.ssh/id_ed25519_makka_ubuntu_sso"
SSH_HOST="m@pgdb.nn.local"
COMPOSE_FILE="infrastructure/docker/docker-compose.db-remote.yml"
ENV_FILE=".env.db"

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

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if .env.db exists
    if [[ ! -f "$ENV_FILE" ]]; then
        log_error "$ENV_FILE not found. Please create it from .env.db.example"
        exit 1
    fi
    
    # Check if SSH key exists
    if [[ ! -f "$SSH_KEY" ]]; then
        log_error "SSH key not found: $SSH_KEY"
        exit 1
    fi
    
    # Check if Docker host is accessible via SSH
    if ! ssh -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new "$SSH_HOST" "sudo docker version" &>/dev/null; then
        log_error "Cannot connect to Docker host: $SSH_HOST"
        log_error "Please ensure SSH access is configured and Docker is running"
        log_error "Also ensure user '$SSH_USER' has sudo access to docker commands"
        exit 1
    fi
    
    # Check if compose file exists
    if [[ ! -f "$COMPOSE_FILE" ]]; then
        log_error "Docker compose file not found: $COMPOSE_FILE"
        exit 1
    fi
    
    log_info "Prerequisites check passed"
}

deploy_databases() {
    log_info "Deploying databases to $SSH_HOST..."
    
    # Load environment variables
    export $(cat $ENV_FILE | grep -v '^#' | xargs)
    
    # Copy compose file and dependencies to remote host
    log_info "Copying configuration files to remote host..."
    ssh -i "$SSH_KEY" "$SSH_HOST" "mkdir -p /tmp/nexanest-deploy"
    scp -i "$SSH_KEY" -r infrastructure/database "$SSH_HOST:/tmp/nexanest-deploy/"
    scp -i "$SSH_KEY" "$COMPOSE_FILE" "$SSH_HOST:/tmp/nexanest-deploy/"
    scp -i "$SSH_KEY" "$ENV_FILE" "$SSH_HOST:/tmp/nexanest-deploy/"
    
    # Copy schema files directly into init directory to avoid mount issues
    log_info "Copying schema files to init directory..."
    ssh -i "$SSH_KEY" "$SSH_HOST" "
        cp /tmp/nexanest-deploy/database/schemas/*.sql /tmp/nexanest-deploy/database/init/ 2>/dev/null || true
    "
    
    # Deploy using docker compose with sudo
    log_info "Starting database containers..."
    ssh -i "$SSH_KEY" "$SSH_HOST" "
        cd /tmp/nexanest-deploy && \
        sudo docker compose -f docker-compose.db-remote.yml --env-file .env.db up -d
    "
    
    log_info "Database deployment initiated"
}

check_health() {
    log_info "Checking database health..."
    
    local max_attempts=30
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        log_info "Health check attempt $attempt/$max_attempts"
        
        # Check PostgreSQL
        if ssh -i "$SSH_KEY" "$SSH_HOST" "sudo docker exec nexanest-postgres pg_isready -U nexanest -d nexanest" &>/dev/null; then
            log_info "PostgreSQL is healthy"
            postgres_healthy=true
        else
            postgres_healthy=false
        fi
        
        # Check TimescaleDB
        if ssh -i "$SSH_KEY" "$SSH_HOST" "sudo docker exec nexanest-timescaledb pg_isready -U timescale -d timescale" &>/dev/null; then
            log_info "TimescaleDB is healthy"
            timescale_healthy=true
        else
            timescale_healthy=false
        fi
        
        # Check Redis (with authentication)
        if ssh -i "$SSH_KEY" "$SSH_HOST" "sudo docker exec nexanest-redis redis-cli -a \${REDIS_PASSWORD:-redis_secure_password_change_me} ping" 2>/dev/null | grep -q PONG; then
            log_info "Redis is healthy"
            redis_healthy=true
        else
            redis_healthy=false
        fi
        
        if [[ "$postgres_healthy" == true && "$timescale_healthy" == true && "$redis_healthy" == true ]]; then
            log_info "All databases are healthy!"
            return 0
        fi
        
        log_warn "Some databases are not ready yet. Waiting 10 seconds..."
        sleep 10
        ((attempt++))
    done
    
    log_error "Health check failed after $max_attempts attempts"
    return 1
}

show_status() {
    log_info "Database service status:"
    ssh -i "$SSH_KEY" "$SSH_HOST" "cd /tmp/nexanest-deploy && sudo docker compose -f docker-compose.db-remote.yml ps"
    
    log_info "Database container logs (last 20 lines):"
    echo "=== PostgreSQL ==="
    ssh -i "$SSH_KEY" "$SSH_HOST" "sudo docker logs --tail 20 nexanest-postgres"
    echo "=== TimescaleDB ==="
    ssh -i "$SSH_KEY" "$SSH_HOST" "sudo docker logs --tail 20 nexanest-timescaledb"
    echo "=== Redis ==="
    ssh -i "$SSH_KEY" "$SSH_HOST" "sudo docker logs --tail 20 nexanest-redis"
}

show_connection_info() {
    log_info "Database connection information:"
    echo ""
    echo "PostgreSQL:"
    echo "  Host: $DB_HOST"
    echo "  Port: 5432"
    echo "  User: nexanest"
    echo "  Databases: auth, portfolio, analytics, notifications"
    echo ""
    echo "TimescaleDB:"
    echo "  Host: $DB_HOST"
    echo "  Port: 5433"
    echo "  User: timescale"
    echo "  Database: timescale"
    echo ""
    echo "Redis:"
    echo "  Host: $DB_HOST"
    echo "  Port: 6379"
    echo ""
    echo "Connection strings are available in your .env.db file"
}

# Command handling
case "${1:-deploy}" in
    "deploy")
        check_prerequisites
        deploy_databases
        if check_health; then
            show_connection_info
        else
            log_error "Deployment completed but health checks failed"
            show_status
            exit 1
        fi
        ;;
    "status")
        show_status
        ;;
    "health")
        if check_health; then
            log_info "All databases are healthy"
        else
            log_error "Some databases are unhealthy"
            exit 1
        fi
        ;;
    "stop")
        log_info "Stopping databases on $SSH_HOST..."
        ssh -i "$SSH_KEY" "$SSH_HOST" "cd /tmp/nexanest-deploy && sudo docker compose -f docker-compose.db-remote.yml down"
        log_info "Databases stopped"
        ;;
    "logs")
        service="${2:-}"
        if [[ -n "$service" ]]; then
            ssh -i "$SSH_KEY" "$SSH_HOST" "sudo docker logs -f nexanest-$service"
        else
            ssh -i "$SSH_KEY" "$SSH_HOST" "cd /tmp/nexanest-deploy && sudo docker compose -f docker-compose.db-remote.yml logs -f"
        fi
        ;;
    "restart")
        log_info "Restarting databases on $SSH_HOST..."
        ssh -i "$SSH_KEY" "$SSH_HOST" "cd /tmp/nexanest-deploy && sudo docker compose -f docker-compose.db-remote.yml restart"
        check_health
        ;;
    "help")
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  deploy    Deploy databases (default)"
        echo "  status    Show service status"
        echo "  health    Check database health"
        echo "  stop      Stop all databases"
        echo "  logs      Show logs (optional service name)"
        echo "  restart   Restart all databases"
        echo "  help      Show this help"
        echo ""
        echo "Examples:"
        echo "  $0 deploy              # Deploy all databases"
        echo "  $0 status              # Show status"
        echo "  $0 logs postgres       # Show PostgreSQL logs"
        echo "  $0 logs                # Show all logs"
        ;;
    *)
        log_error "Unknown command: $1"
        echo "Use '$0 help' for usage information"
        exit 1
        ;;
esac