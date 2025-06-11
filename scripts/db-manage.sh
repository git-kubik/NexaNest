#!/bin/bash

# NexaNest Database Management Script
# Manages PostgreSQL, TimescaleDB, and Redis databases outside Docker Swarm

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Environment file
ENV_FILE="$PROJECT_ROOT/.env.db"

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

# Function to check if environment file exists
check_env_file() {
    if [ ! -f "$ENV_FILE" ]; then
        print_warning "Environment file $ENV_FILE not found"
        print_status "Copying from .env.db.example..."
        cp "$PROJECT_ROOT/.env.db.example" "$ENV_FILE"
        print_warning "Please edit $ENV_FILE with your database passwords"
        return 1
    fi
    return 0
}

# Function to start databases
start_databases() {
    print_status "Starting NexaNest databases..."
    
    if ! check_env_file; then
        print_error "Please configure $ENV_FILE before starting databases"
        exit 1
    fi
    
    cd "$PROJECT_ROOT"
    docker-compose -f infrastructure/docker/docker-compose.db.yml --env-file "$ENV_FILE" up -d
    
    print_success "Databases started successfully!"
    print_status "Waiting for databases to be ready..."
    
    # Wait for PostgreSQL
    print_status "Waiting for PostgreSQL..."
    timeout 60 bash -c 'until docker exec nexanest-postgres pg_isready -U nexanest; do sleep 2; done'
    
    # Wait for TimescaleDB
    print_status "Waiting for TimescaleDB..."
    timeout 60 bash -c 'until docker exec nexanest-timescaledb pg_isready -U timescale; do sleep 2; done'
    
    # Wait for Redis
    print_status "Waiting for Redis..."
    timeout 60 bash -c 'until docker exec nexanest-redis redis-cli ping; do sleep 2; done'
    
    print_success "All databases are ready!"
    show_status
}

# Function to stop databases
stop_databases() {
    print_status "Stopping NexaNest databases..."
    cd "$PROJECT_ROOT"
    docker-compose -f infrastructure/docker/docker-compose.db.yml down
    print_success "Databases stopped successfully!"
}

# Function to restart databases
restart_databases() {
    stop_databases
    start_databases
}

# Function to show database status
show_status() {
    print_status "Database Status:"
    echo ""
    docker-compose -f "$PROJECT_ROOT/infrastructure/docker/docker-compose.db.yml" ps
    echo ""
    print_status "Connection Information:"
    echo "  PostgreSQL:  localhost:5432 (databases: auth, portfolio, analytics, notifications)"
    echo "  TimescaleDB: localhost:5433 (database: timescale)"
    echo "  Redis:       localhost:6379"
    echo "  PgAdmin:     http://localhost:5050"
}

# Function to create database backup
backup_databases() {
    print_status "Creating database backups..."
    
    BACKUP_DIR="$PROJECT_ROOT/backups/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    
    # Backup PostgreSQL databases
    for db in auth portfolio analytics notifications; do
        print_status "Backing up PostgreSQL database: $db"
        docker exec nexanest-postgres pg_dump -U nexanest -d "$db" | gzip > "$BACKUP_DIR/postgres_${db}.sql.gz"
    done
    
    # Backup TimescaleDB
    print_status "Backing up TimescaleDB..."
    docker exec nexanest-timescaledb pg_dump -U timescale -d timescale | gzip > "$BACKUP_DIR/timescale.sql.gz"
    
    # Backup Redis
    print_status "Backing up Redis..."
    docker exec nexanest-redis redis-cli --rdb /data/backup.rdb
    docker cp nexanest-redis:/data/backup.rdb "$BACKUP_DIR/redis_backup.rdb"
    
    print_success "Backups created in: $BACKUP_DIR"
}

# Function to restore database backup
restore_databases() {
    if [ -z "$1" ]; then
        print_error "Usage: $0 restore <backup_directory>"
        exit 1
    fi
    
    BACKUP_DIR="$1"
    if [ ! -d "$BACKUP_DIR" ]; then
        print_error "Backup directory $BACKUP_DIR not found"
        exit 1
    fi
    
    print_warning "This will restore databases from: $BACKUP_DIR"
    read -p "Are you sure? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Restore cancelled"
        exit 0
    fi
    
    # Restore PostgreSQL databases
    for db in auth portfolio analytics notifications; do
        if [ -f "$BACKUP_DIR/postgres_${db}.sql.gz" ]; then
            print_status "Restoring PostgreSQL database: $db"
            zcat "$BACKUP_DIR/postgres_${db}.sql.gz" | docker exec -i nexanest-postgres psql -U nexanest -d "$db"
        fi
    done
    
    # Restore TimescaleDB
    if [ -f "$BACKUP_DIR/timescale.sql.gz" ]; then
        print_status "Restoring TimescaleDB..."
        zcat "$BACKUP_DIR/timescale.sql.gz" | docker exec -i nexanest-timescaledb psql -U timescale -d timescale
    fi
    
    # Restore Redis
    if [ -f "$BACKUP_DIR/redis_backup.rdb" ]; then
        print_status "Restoring Redis..."
        docker cp "$BACKUP_DIR/redis_backup.rdb" nexanest-redis:/data/dump.rdb
        docker restart nexanest-redis
    fi
    
    print_success "Database restore completed!"
}

# Function to run database migrations
run_migrations() {
    print_status "Running database migrations..."
    
    # This will be implemented when we create the migration scripts
    print_warning "Migration scripts not yet implemented"
    print_status "Databases are initialized with base schemas"
}

# Function to show logs
show_logs() {
    cd "$PROJECT_ROOT"
    docker-compose -f infrastructure/docker/docker-compose.db.yml logs -f
}

# Function to connect to PostgreSQL
connect_postgres() {
    print_status "Connecting to PostgreSQL..."
    docker exec -it nexanest-postgres psql -U nexanest -d nexanest
}

# Function to connect to TimescaleDB
connect_timescale() {
    print_status "Connecting to TimescaleDB..."
    docker exec -it nexanest-timescaledb psql -U timescale -d timescale
}

# Function to connect to Redis
connect_redis() {
    print_status "Connecting to Redis..."
    docker exec -it nexanest-redis redis-cli
}

# Function to show help
show_help() {
    echo "NexaNest Database Management Script"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  start       Start all databases"
    echo "  stop        Stop all databases"
    echo "  restart     Restart all databases"
    echo "  status      Show database status"
    echo "  backup      Create database backups"
    echo "  restore     Restore database from backup"
    echo "  migrate     Run database migrations"
    echo "  logs        Show database logs"
    echo "  psql        Connect to PostgreSQL"
    echo "  timescale   Connect to TimescaleDB"
    echo "  redis       Connect to Redis CLI"
    echo "  help        Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 start                     # Start all databases"
    echo "  $0 backup                    # Create backup"
    echo "  $0 restore ./backups/backup  # Restore from backup"
}

# Main script logic
case "${1:-help}" in
    start)
        start_databases
        ;;
    stop)
        stop_databases
        ;;
    restart)
        restart_databases
        ;;
    status)
        show_status
        ;;
    backup)
        backup_databases
        ;;
    restore)
        restore_databases "$2"
        ;;
    migrate)
        run_migrations
        ;;
    logs)
        show_logs
        ;;
    psql)
        connect_postgres
        ;;
    timescale)
        connect_timescale
        ;;
    redis)
        connect_redis
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