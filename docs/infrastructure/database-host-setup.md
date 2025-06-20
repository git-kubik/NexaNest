---
title: "Database Host Setup - pgdb.nn.local"
description: "Setup and configuration guide for the dedicated database host pgdb.nn.local with SSH access and Docker deployment"
authors:
  - "Infrastructure Team"
  - "Database Team"
datetime: "2025-06-20 21:30:00"
status: "approved"
tags:
  - "database"
  - "infrastructure"
  - "ssh"
  - "docker"
  - "deployment"
category: "operations"
audience: "developer"
complexity: "intermediate"
technology_stack:
  - "Docker"
  - "SSH"
  - "PostgreSQL"
  - "TimescaleDB"
  - "Redis"
platforms:
  - "Linux"
  - "Ubuntu"
business_value: "high"
---

# Database Host Setup - pgdb.nn.local

This guide covers the setup and configuration of the dedicated database host `pgdb.nn.local` for the NexaNest platform.

## Overview

The NexaNest database infrastructure uses a dedicated Docker host (`pgdb.nn.local`) that's part of the swarm but used as a standalone Docker host for database services. This approach provides:

- **Isolation**: Database services run on dedicated hardware
- **Performance**: Optimized for database workloads
- **Security**: Controlled access via SSH with key-based authentication
- **Flexibility**: Independent scaling and maintenance

## Architecture

```mermaid
graph TB
    subgraph "Development Environment"
        DEV_SERVICES[Application Services<br/>Local Development]
    end
    
    subgraph "pgdb.nn.local"
        POSTGRES[(PostgreSQL<br/>Port 5432)]
        TIMESCALE[(TimescaleDB<br/>Port 5433)]
        REDIS[(Redis<br/>Port 6379)]
    end
    
    subgraph "SSH Access"
        SSH_USER[User: m]
        SSH_KEY[Key: id_ed25519_makka_ubuntu_sso]
        SUDO[sudo docker commands]
    end
    
    DEV_SERVICES -.-> POSTGRES
    DEV_SERVICES -.-> TIMESCALE
    DEV_SERVICES -.-> REDIS
    
    SSH_USER --> SSH_KEY
    SSH_KEY --> SUDO
    SUDO --> POSTGRES
    SUDO --> TIMESCALE
    SUDO --> REDIS
    
    style POSTGRES fill:#336791,color:#fff
    style TIMESCALE fill:#FDB515,color:#000
    style REDIS fill:#DC382D,color:#fff
```

## SSH Configuration

### Access Details

- **Host**: `pgdb.nn.local`
- **User**: `m`
- **SSH Key**: `/home/m/.ssh/id_ed25519_makka_ubuntu_sso`
- **Docker Access**: Via `sudo` (user `m` requires sudo for Docker commands)

### SSH Setup

1. **Verify SSH Key Exists**:
   ```bash
   ls -la /home/m/.ssh/id_ed25519_makka_ubuntu_sso
   chmod 600 /home/m/.ssh/id_ed25519_makka_ubuntu_sso
   ```

2. **Test SSH Connection**:
   ```bash
   ssh -i /home/m/.ssh/id_ed25519_makka_ubuntu_sso m@pgdb.nn.local
   ```

3. **Test Docker Access**:
   ```bash
   ssh -i /home/m/.ssh/id_ed25519_makka_ubuntu_sso m@pgdb.nn.local "sudo docker version"
   ```

4. **Automated Setup**:
   ```bash
   ./scripts/setup-ssh-access.sh setup
   ```

### SSH Config Entry

Add to `~/.ssh/config`:

```ssh-config
# NexaNest Database Host
Host pgdb.nn.local
    HostName pgdb.nn.local
    User m
    IdentityFile /home/m/.ssh/id_ed25519_makka_ubuntu_sso
    IdentitiesOnly yes
    StrictHostKeyChecking accept-new
    ServerAliveInterval 60
    ServerAliveCountMax 3
```

## Database Deployment

### Automated Deployment

Use the provided deployment script:

```bash
# Deploy all databases
./scripts/deploy-database.sh deploy

# Check status
./scripts/deploy-database.sh status

# Check health
./scripts/deploy-database.sh health

# View logs
./scripts/deploy-database.sh logs postgres
./scripts/deploy-database.sh logs timescaledb
./scripts/deploy-database.sh logs redis

# Stop databases
./scripts/deploy-database.sh stop

# Restart databases
./scripts/deploy-database.sh restart
```

### Manual Deployment

1. **Copy Files to Remote Host**:
   ```bash
   # Create deployment directory
   ssh -i /home/m/.ssh/id_ed25519_makka_ubuntu_sso m@pgdb.nn.local "mkdir -p /tmp/nexanest-deploy"
   
   # Copy configuration files
   scp -i /home/m/.ssh/id_ed25519_makka_ubuntu_sso -r infrastructure/database m@pgdb.nn.local:/tmp/nexanest-deploy/
   scp -i /home/m/.ssh/id_ed25519_makka_ubuntu_sso infrastructure/docker/docker-compose.db-remote.yml m@pgdb.nn.local:/tmp/nexanest-deploy/
   scp -i /home/m/.ssh/id_ed25519_makka_ubuntu_sso .env.db m@pgdb.nn.local:/tmp/nexanest-deploy/
   ```

2. **Deploy Databases**:
   ```bash
   ssh -i /home/m/.ssh/id_ed25519_makka_ubuntu_sso m@pgdb.nn.local "
       cd /tmp/nexanest-deploy && \
       sudo docker compose -f docker-compose.db-remote.yml --env-file .env.db up -d
   "
   ```

3. **Verify Deployment**:
   ```bash
   ssh -i /home/m/.ssh/id_ed25519_makka_ubuntu_sso m@pgdb.nn.local "sudo docker ps"
   ```

## Database Services

### PostgreSQL (Port 5432) - ✅ DEPLOYED

```yaml
Container: nexanest-postgres
Image: postgres:15
Status: Running and Healthy
Databases:
  - nexanest (main)
  - auth (with schema)
  - portfolio (with schema)
  - analytics (ready for implementation)
  - notifications (ready for implementation)
User: nexanest
Deployment Date: 2025-06-20
```

**Connection String**:
```
postgresql://nexanest:${POSTGRES_PASSWORD}@pgdb.nn.local:5432/{database_name}
```

### TimescaleDB (Port 5433) - ✅ DEPLOYED

```yaml
Container: nexanest-timescaledb
Image: timescale/timescaledb:latest-pg15
Status: Running and Healthy
Database: timescale
User: timescale
Deployment Date: 2025-06-20
```

**Connection String**:
```
postgresql://timescale:${TIMESCALE_PASSWORD}@pgdb.nn.local:5433/timescale
```

### Redis (Port 6379) - ✅ DEPLOYED

```yaml
Container: nexanest-redis
Image: redis:7-alpine
Status: Running and Healthy
Password: ${REDIS_PASSWORD}
Persistence: AOF enabled
Deployment Date: 2025-06-20
```

**Connection String**:
```
redis://:${REDIS_PASSWORD}@pgdb.nn.local:6379/{db_number}
```

## Environment Configuration

### .env.db Configuration

```bash
# Database Host Configuration
DB_HOST=pgdb.nn.local

# SSH Configuration for remote Docker access
SSH_USER=m
SSH_KEY=/home/m/.ssh/id_ed25519_makka_ubuntu_sso
SSH_HOST=m@pgdb.nn.local

# PostgreSQL Configuration
POSTGRES_HOST=${DB_HOST}
POSTGRES_PORT=5432
POSTGRES_USER=nexanest
POSTGRES_PASSWORD=nexanest_secure_password_change_me

# TimescaleDB Configuration
TIMESCALE_HOST=${DB_HOST}
TIMESCALE_PORT=5433
TIMESCALE_USER=timescale
TIMESCALE_PASSWORD=timescale_secure_password_change_me

# Redis Configuration
REDIS_HOST=${DB_HOST}
REDIS_PORT=6379
REDIS_PASSWORD=redis_secure_password_change_me
```

## Security Considerations

### SSH Security

1. **Key-based Authentication**: Only SSH key access, no password authentication
2. **Specific User**: Limited to user `m` with restricted permissions
3. **Key Permissions**: SSH key must have 600 permissions
4. **Connection Monitoring**: SSH alive intervals to maintain connections

### Docker Security

1. **Sudo Access**: User `m` requires sudo for Docker commands
2. **Container Isolation**: Databases run in isolated containers
3. **Network Security**: Containers on dedicated network
4. **Volume Permissions**: Proper volume permissions and ownership

### Database Security

1. **Password Protection**: Strong passwords for all database users
2. **Network Isolation**: Databases only accessible via specific ports
3. **SSL/TLS**: Encrypted connections in production
4. **Access Control**: Role-based access within databases

## Monitoring and Health Checks

### Health Check Commands

```bash
# PostgreSQL
ssh -i /home/m/.ssh/id_ed25519_makka_ubuntu_sso m@pgdb.nn.local "sudo docker exec nexanest-postgres pg_isready -U nexanest"

# TimescaleDB
ssh -i /home/m/.ssh/id_ed25519_makka_ubuntu_sso m@pgdb.nn.local "sudo docker exec nexanest-timescaledb pg_isready -U timescale"

# Redis
ssh -i /home/m/.ssh/id_ed25519_makka_ubuntu_sso m@pgdb.nn.local "sudo docker exec nexanest-redis redis-cli ping"
```

### Container Status

```bash
# View running containers
ssh -i /home/m/.ssh/id_ed25519_makka_ubuntu_sso m@pgdb.nn.local "sudo docker ps"

# View container logs
ssh -i /home/m/.ssh/id_ed25519_makka_ubuntu_sso m@pgdb.nn.local "sudo docker logs nexanest-postgres"
ssh -i /home/m/.ssh/id_ed25519_makka_ubuntu_sso m@pgdb.nn.local "sudo docker logs nexanest-timescaledb"
ssh -i /home/m/.ssh/id_ed25519_makka_ubuntu_sso m@pgdb.nn.local "sudo docker logs nexanest-redis"
```

### Resource Monitoring

```bash
# Container resource usage
ssh -i /home/m/.ssh/id_ed25519_makka_ubuntu_sso m@pgdb.nn.local "sudo docker stats"

# System resources
ssh -i /home/m/.ssh/id_ed25519_makka_ubuntu_sso m@pgdb.nn.local "top"
ssh -i /home/m/.ssh/id_ed25519_makka_ubuntu_sso m@pgdb.nn.local "df -h"
```

## Troubleshooting

### Common Issues

1. **SSH Connection Failed**
   ```bash
   # Check key permissions
   chmod 600 /home/m/.ssh/id_ed25519_makka_ubuntu_sso
   
   # Test with verbose output
   ssh -i /home/m/.ssh/id_ed25519_makka_ubuntu_sso -v m@pgdb.nn.local
   
   # Check host connectivity
   ping pgdb.nn.local
   ```

2. **Docker Permission Denied**
   ```bash
   # Verify sudo access
   ssh -i /home/m/.ssh/id_ed25519_makka_ubuntu_sso m@pgdb.nn.local "sudo -l"
   
   # Test Docker access
   ssh -i /home/m/.ssh/id_ed25519_makka_ubuntu_sso m@pgdb.nn.local "sudo docker version"
   ```

3. **Container Won't Start**
   ```bash
   # Check container logs
   ssh -i /home/m/.ssh/id_ed25519_makka_ubuntu_sso m@pgdb.nn.local "sudo docker logs nexanest-postgres"
   
   # Check port availability
   ssh -i /home/m/.ssh/id_ed25519_makka_ubuntu_sso m@pgdb.nn.local "sudo netstat -tulpn | grep :5432"
   
   # Check disk space
   ssh -i /home/m/.ssh/id_ed25519_makka_ubuntu_sso m@pgdb.nn.local "df -h"
   ```

4. **Connection Refused from Applications**
   ```bash
   # Test connectivity from local machine
   telnet pgdb.nn.local 5432
   telnet pgdb.nn.local 5433
   telnet pgdb.nn.local 6379
   
   # Check firewall settings
   ssh -i /home/m/.ssh/id_ed25519_makka_ubuntu_sso m@pgdb.nn.local "sudo ufw status"
   ```

### Recovery Procedures

1. **Database Container Recovery**
   ```bash
   # Stop and remove containers
   ssh -i /home/m/.ssh/id_ed25519_makka_ubuntu_sso m@pgdb.nn.local "cd /tmp/nexanest-deploy && sudo docker compose -f docker-compose.db-remote.yml down"
   
   # Start fresh
   ./scripts/deploy-database.sh deploy
   ```

2. **Data Volume Recovery**
   ```bash
   # List volumes
   ssh -i /home/m/.ssh/id_ed25519_makka_ubuntu_sso m@pgdb.nn.local "sudo docker volume ls"
   
   # Backup volumes (if needed)
   ssh -i /home/m/.ssh/id_ed25519_makka_ubuntu_sso m@pgdb.nn.local "sudo docker run --rm -v postgres_data:/data -v /tmp:/backup alpine tar czf /backup/postgres_backup.tar.gz -C /data ."
   ```

## Maintenance

### Regular Tasks

1. **Update Docker Images**
   ```bash
   # Pull latest images
   ssh -i /home/m/.ssh/id_ed25519_makka_ubuntu_sso m@pgdb.nn.local "sudo docker pull postgres:15"
   ssh -i /home/m/.ssh/id_ed25519_makka_ubuntu_sso m@pgdb.nn.local "sudo docker pull timescale/timescaledb:latest-pg15"
   ssh -i /home/m/.ssh/id_ed25519_makka_ubuntu_sso m@pgdb.nn.local "sudo docker pull redis:7-alpine"
   
   # Recreate containers
   ./scripts/deploy-database.sh restart
   ```

2. **Database Backups**
   ```bash
   # PostgreSQL backup
   ssh -i /home/m/.ssh/id_ed25519_makka_ubuntu_sso m@pgdb.nn.local "sudo docker exec nexanest-postgres pg_dumpall -U nexanest > /tmp/postgres_backup_$(date +%Y%m%d).sql"
   
   # TimescaleDB backup
   ssh -i /home/m/.ssh/id_ed25519_makka_ubuntu_sso m@pgdb.nn.local "sudo docker exec nexanest-timescaledb pg_dump -U timescale timescale > /tmp/timescale_backup_$(date +%Y%m%d).sql"
   ```

3. **Log Rotation**
   ```bash
   # Configure log rotation for Docker containers
   ssh -i /home/m/.ssh/id_ed25519_makka_ubuntu_sso m@pgdb.nn.local "sudo docker system prune -f"
   ```

## Scripts Reference

- `scripts/setup-ssh-access.sh` - Configure SSH access to pgdb.nn.local
- `scripts/deploy-database.sh` - Deploy and manage databases on remote host
- `infrastructure/docker/docker-compose.db-remote.yml` - Database services configuration

## Related Documentation

- [Database Connectivity Guide](../database/connectivity.md)
- [ADR-015: Database Deployment Strategy](../architecture/adr-015-database-deployment-strategy.md)
- [SSH Access Setup Guide](ssh-access-setup.md)
- [Database Schema Documentation](../database/schemas/index.md)