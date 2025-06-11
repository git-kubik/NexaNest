# NexaNest Database Infrastructure

This directory contains the database configuration and setup for the NexaNest project.

## Overview

The database setup includes:
- **PostgreSQL**: Main application database with separate databases per service
- **TimescaleDB**: Time-series database for market data and analytics  
- **Redis**: Caching and session storage
- **PgAdmin**: Web-based database management interface

## Quick Start

1. **Configure environment variables:**
   ```bash
   cp .env.db.example .env.db
   # Edit .env.db with your passwords
   ```

2. **Start databases:**
   ```bash
   make db-start
   # or
   ./scripts/db-manage.sh start
   ```

3. **Check status:**
   ```bash
   make db-status
   ```

## Database Structure

### PostgreSQL Databases
- `nexanest` - Main database
- `auth` - Authentication service data
- `portfolio` - Portfolio management data  
- `analytics` - Analytics and reporting data
- `notifications` - Notification service data

### TimescaleDB
- `timescale` - Time-series data for market prices, analytics, and events

### Redis
- Database 0: General caching
- Database 1: Cache-specific data
- Database 2: Session storage

## Connection Information

| Service | Host | Port | Database | User |
|---------|------|------|----------|------|
| PostgreSQL | localhost | 5432 | auth/portfolio/etc | nexanest |
| TimescaleDB | localhost | 5433 | timescale | timescale |
| Redis | localhost | 6379 | 0-15 | N/A |
| PgAdmin | localhost | 5050 | N/A | admin@nexanest.local |

## Management Commands

```bash
# Basic operations
make db-start          # Start all databases
make db-stop           # Stop all databases  
make db-restart        # Restart all databases
make db-status         # Show status
make db-logs           # Show logs

# Database connections
make db-connect-postgres   # Connect to PostgreSQL
make db-connect-timescale  # Connect to TimescaleDB
make db-connect-redis      # Connect to Redis

# Backup and restore
make db-backup         # Create backup
./scripts/db-manage.sh restore /path/to/backup
```

## File Structure

```
infrastructure/
├── database/                 # Database configurations and schemas
│   ├── init/                # Initialization scripts
│   │   ├── 01-create-databases.sql
│   │   └── 02-apply-schemas.sql
│   ├── schemas/             # Service-specific schemas
│   │   ├── auth-schema.sql
│   │   └── portfolio-schema.sql
│   ├── postgres.conf        # PostgreSQL configuration
│   ├── redis.conf          # Redis configuration
│   ├── pgadmin-servers.json # PgAdmin server configuration
│   └── timescale-init/      # TimescaleDB initialization
│       └── 01-setup-timescale.sql
└── docker/                  # Docker Compose configurations
    ├── docker-compose.yml      # Main services
    ├── docker-compose.db.yml   # Database services
    └── docker-compose.swarm.yml # Docker Swarm stack
```

## Database Schemas

### Auth Service Schema (`auth` database)
- `users` - User accounts and authentication
- `user_profiles` - Extended user profile information
- `refresh_tokens` - JWT refresh token management
- `api_keys` - Service-to-service authentication
- `password_reset_tokens` - Password reset functionality
- `email_verification_tokens` - Email verification
- `login_attempts` - Rate limiting and security
- `user_sessions` - Session management

### Portfolio Service Schema (`portfolio` database)
- `portfolios` - User investment portfolios
- `holdings` - Individual stock/asset positions
- `transactions` - Buy/sell/dividend transactions
- `portfolio_snapshots` - Daily performance snapshots
- `benchmarks` - Market index benchmarks
- `watchlists` - User watchlists and alerts
- `portfolio_goals` - Investment goals and targets
- `allocation_rules` - Asset allocation rules

### TimescaleDB Schema (`timescale` database)
- `market_data.stock_prices` - Real-time stock prices (hypertable)
- `market_data.market_indices` - Market index values (hypertable)
- `market_data.currency_rates` - Currency exchange rates (hypertable)
- `analytics_ts.portfolio_snapshots` - Portfolio performance over time
- `analytics_ts.risk_metrics` - Risk calculations over time
- `events.system_events` - System audit trail (hypertable)
- `events.trading_events` - Trading activity log (hypertable)

## Security Features

- **Row Level Security (RLS)**: Users can only access their own data
- **Database Isolation**: Each service has its own database
- **Password Authentication**: All databases require authentication
- **Network Isolation**: Databases run in isolated Docker network
- **Backup Encryption**: Database backups can be encrypted

## Performance Optimizations

### PostgreSQL
- Optimized for development and small-scale production
- Connection pooling ready
- Query performance monitoring enabled
- Automatic vacuum and analyze

### TimescaleDB
- Automatic data partitioning by time
- Continuous aggregates for common queries
- Data retention policies for automatic cleanup
- Optimized for time-series queries

### Redis
- LRU eviction policy for memory management
- AOF persistence for durability
- Keyspace notifications for real-time updates

## Environment Variables

See `.env.db.example` for all available configuration options:

- `POSTGRES_PASSWORD` - PostgreSQL password
- `TIMESCALE_PASSWORD` - TimescaleDB password  
- `REDIS_PASSWORD` - Redis password
- `PGADMIN_EMAIL` - PgAdmin login email
- `PGADMIN_PASSWORD` - PgAdmin password

## Backup and Recovery

### Automatic Backups
- PostgreSQL: Daily automatic backups with retention
- TimescaleDB: Continuous backups with point-in-time recovery
- Redis: AOF and RDB persistence

### Manual Backups
```bash
make db-backup  # Creates timestamped backup in ./backups/
```

### Restore Process
```bash
./scripts/db-manage.sh restore ./backups/20250531_123456/
```

## Monitoring and Alerts

### Built-in Monitoring
- PostgreSQL: pg_stat_statements for query performance
- TimescaleDB: Built-in monitoring views
- Redis: INFO command for statistics

### Health Checks
- All containers have health check endpoints
- Automatic restart on failure
- Status monitoring via `make db-status`

## Troubleshooting

### Common Issues

1. **Database won't start**
   ```bash
   make db-logs  # Check logs for errors
   ```

2. **Connection refused**
   ```bash
   make db-status  # Verify containers are running
   ```

3. **Permission denied**
   ```bash
   # Check .env.db file has correct passwords
   # Verify Docker has permission to access volumes
   ```

4. **Out of disk space**
   ```bash
   docker system prune  # Clean up unused containers/images
   ```

### Log Analysis
```bash
make db-logs                    # All database logs
docker logs nexanest-postgres   # PostgreSQL specific
docker logs nexanest-timescaledb # TimescaleDB specific
docker logs nexanest-redis      # Redis specific
```

## Development vs Production

This setup is optimized for development. For production:

1. **Security**: Change all default passwords
2. **SSL**: Enable SSL/TLS connections
3. **Backup**: Set up automated backup system
4. **Monitoring**: Add comprehensive monitoring
5. **Resources**: Tune memory and CPU settings
6. **High Availability**: Consider read replicas and failover

## Data Migration

When ready to move to production:

1. Export development data: `make db-backup`
2. Set up production databases
3. Import data: `./scripts/db-manage.sh restore`
4. Update connection strings in services

## Compliance

The database setup supports:
- **GDPR**: User data deletion and export capabilities
- **SOC 2**: Audit trails and access controls
- **Financial regulations**: Transaction logging and reporting