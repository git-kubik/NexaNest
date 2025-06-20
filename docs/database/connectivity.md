---
title: "Database Connectivity Guide"
description: "Database connections, service communication patterns, and network architecture for NexaNest platform"
authors:
  - "Database Team"
  - "DevOps Team"
datetime: "2025-11-06 14:15:00"
status: "approved"
tags:
  - "database"
  - "connectivity"
  - "networking"
  - "security"
  - "configuration"
category: "operations"
audience: "developer"
complexity: "intermediate"
technology_stack:
  - "PostgreSQL"
  - "TimescaleDB"
  - "Redis"
  - "Docker"
platforms:
  - "Linux"
  - "Docker"
business_value: "high"
---

# Database Connectivity Guide

This guide covers database connections, service communication patterns, and network architecture for the NexaNest platform.

## Architecture Overview

```mermaid
graph TB
    subgraph "Application Layer"
        AUTH[Auth Service<br/>Port 8001]
        PORTFOLIO[Portfolio Service<br/>Port 8002]
        MARKET[Market Data Service<br/>Port 8003]
        ML[AI/ML Service<br/>Port 8004]
        ANALYTICS[Analytics Service<br/>Port 8005]
        NOTIF[Notification Service<br/>Port 8006]
    end
    
    subgraph "API Gateway"
        GATEWAY[API Gateway<br/>Port 8000]
    end
    
    subgraph "Database Layer"
        subgraph "PostgreSQL Cluster"
            PG_MASTER[(PostgreSQL Master<br/>Port 5432)]
            PG_REPLICA[(PostgreSQL Replica<br/>Port 5433)]
        end
        
        subgraph "TimescaleDB"
            TS[(TimescaleDB<br/>Port 5433)]
        end
        
        subgraph "Cache Layer"
            REDIS[(Redis<br/>Port 6379)]
        end
        
        subgraph "Management"
            PGADMIN[PgAdmin<br/>Port 5050]
        end
    end
    
    subgraph "Client Applications"
        WEB[Web Frontend<br/>Port 3000]
        MOBILE[Mobile Apps]
        API_CLIENTS[API Clients]
    end
    
    subgraph "External Services"
        MARKET_FEED[Market Data Feeds]
        AI_PROVIDERS[AI/ML Providers]
    end
    
    %% Client connections
    WEB --> GATEWAY
    MOBILE --> GATEWAY
    API_CLIENTS --> GATEWAY
    
    %% Gateway routing
    GATEWAY --> AUTH
    GATEWAY --> PORTFOLIO
    GATEWAY --> MARKET
    GATEWAY --> ML
    GATEWAY --> ANALYTICS
    GATEWAY --> NOTIF
    
    %% Database connections
    AUTH --> PG_MASTER
    AUTH --> REDIS
    
    PORTFOLIO --> PG_MASTER
    PORTFOLIO --> TS
    PORTFOLIO --> REDIS
    
    MARKET --> TS
    MARKET --> REDIS
    
    ML --> PG_MASTER
    ML --> TS
    ML --> REDIS
    
    ANALYTICS --> PG_MASTER
    ANALYTICS --> PG_REPLICA
    ANALYTICS --> TS
    ANALYTICS --> REDIS
    
    NOTIF --> PG_MASTER
    NOTIF --> REDIS
    
    %% Management connections
    PGADMIN --> PG_MASTER
    PGADMIN --> TS
    
    %% External connections
    MARKET --> MARKET_FEED
    ML --> AI_PROVIDERS
    
    %% Styling
    style PG_MASTER fill:#336791,color:#fff
    style PG_REPLICA fill:#4a90a4,color:#fff
    style TS fill:#FDB515,color:#000
    style REDIS fill:#DC382D,color:#fff
    style GATEWAY fill:#17a2b8,color:#fff
```

## Connection Details

### PostgreSQL Connections

#### Primary Database (Port 5432)
```yaml
Host: pgdb.nn.local (development) / postgres.nexanest.internal (production)
Port: 5432
Databases:
  - nexanest (main)
  - auth (authentication service)
  - portfolio (portfolio management)
  - analytics (analytics service)
  - notifications (notification service)
User: nexanest
Password: ${POSTGRES_PASSWORD}
SSL: required (production)
Connection Pool: 20 connections per service
```

#### Connection Strings by Service

**Auth Service**
```
postgresql://nexanest:${POSTGRES_PASSWORD}@pgdb.nn.local:5432/auth
```

**Portfolio Service**
```
postgresql://nexanest:${POSTGRES_PASSWORD}@pgdb.nn.local:5432/portfolio
```

**Analytics Service**
```
# Primary (writes)
postgresql://nexanest:${POSTGRES_PASSWORD}@pgdb.nn.local:5432/analytics

# Replica (reads) - future implementation
postgresql://nexanest:${POSTGRES_PASSWORD}@pgdb.nn.local:5433/analytics
```

**Notification Service**
```
postgresql://nexanest:${POSTGRES_PASSWORD}@pgdb.nn.local:5432/notifications
```

### TimescaleDB Connections

#### Time-Series Database (Port 5433)
```yaml
Host: pgdb.nn.local (development) / timescale.nexanest.internal (production)
Port: 5433
Database: timescale
User: timescale
Password: ${TIMESCALE_PASSWORD}
SSL: required (production)
Connection Pool: 50 connections (high throughput)
```

#### Connection String
```
postgresql://timescale:${TIMESCALE_PASSWORD}@pgdb.nn.local:5433/timescale
```

**Used by:**
- Market Data Service (primary)
- Portfolio Service (snapshots)
- Analytics Service (metrics)
- AI/ML Service (training data)

### Redis Connections

#### Cache and Sessions (Port 6379)
```yaml
Host: pgdb.nn.local (development) / redis.nexanest.internal (production)
Port: 6379
Password: ${REDIS_PASSWORD}
SSL: enabled (production)
Database Allocation:
  0: General application cache
  1: Market data cache
  2: User sessions
  3: Real-time notifications
  4: ML model cache
  5: Analytics cache
```

#### Connection Strings by Service

**Auth Service (Sessions)**
```
redis://:${REDIS_PASSWORD}@pgdb.nn.local:6379/2
```

**Portfolio Service (Cache)**
```
redis://:${REDIS_PASSWORD}@pgdb.nn.local:6379/0
```

**Market Data Service (Real-time)**
```
redis://:${REDIS_PASSWORD}@pgdb.nn.local:6379/1
```

**Analytics Service**
```
redis://:${REDIS_PASSWORD}@pgdb.nn.local:6379/5
```

**Notification Service**
```
redis://:${REDIS_PASSWORD}@pgdb.nn.local:6379/3
```

**AI/ML Service**
```
redis://:${REDIS_PASSWORD}@pgdb.nn.local:6379/4
```

## Service Communication Patterns

### Database Access Patterns

```mermaid
sequenceDiagram
    participant Client
    participant Gateway
    participant Auth
    participant Portfolio
    participant Market
    participant PG as PostgreSQL
    participant TS as TimescaleDB
    participant Redis
    
    %% User authentication
    Client->>Gateway: Login Request
    Gateway->>Auth: Validate Credentials
    Auth->>PG: Query auth.users
    PG-->>Auth: User Data
    Auth->>Redis: Store Session
    Auth-->>Gateway: JWT Token
    Gateway-->>Client: Authentication Response
    
    %% Portfolio data request
    Client->>Gateway: Get Portfolio
    Gateway->>Portfolio: Portfolio Request (with JWT)
    Portfolio->>Redis: Check Cache
    alt Cache Hit
        Redis-->>Portfolio: Cached Data
    else Cache Miss
        Portfolio->>PG: Query portfolio tables
        PG-->>Portfolio: Portfolio Data
        Portfolio->>Redis: Update Cache
    end
    Portfolio-->>Gateway: Portfolio Response
    Gateway-->>Client: Portfolio Data
    
    %% Real-time market data
    Market->>TS: Store Price Update
    Market->>Redis: Cache Latest Prices
    Market->>Portfolio: Price Update Event
    Portfolio->>PG: Update Holdings
```

### Cross-Service Data Access

#### Service-to-Service Authentication
```mermaid
graph LR
    subgraph "Service Authentication"
        API_KEY[API Key]
        JWT[JWT Token]
        SERVICE_TOKEN[Service Token]
    end
    
    subgraph "Database Access"
        AUTH_DB[(auth)]
        PORTFOLIO_DB[(portfolio)]
        ANALYTICS_DB[(analytics)]
    end
    
    AUTH_SERVICE[Auth Service] --> AUTH_DB
    AUTH_SERVICE --> API_KEY
    
    PORTFOLIO_SERVICE[Portfolio Service] --> PORTFOLIO_DB
    PORTFOLIO_SERVICE --> SERVICE_TOKEN
    PORTFOLIO_SERVICE -.-> AUTH_DB
    
    ANALYTICS_SERVICE[Analytics Service] --> ANALYTICS_DB
    ANALYTICS_SERVICE --> SERVICE_TOKEN
    ANALYTICS_SERVICE -.-> AUTH_DB
    ANALYTICS_SERVICE -.-> PORTFOLIO_DB
```

## Connection Pooling

### PostgreSQL Connection Pools

```yaml
# Auth Service
auth_service:
  max_connections: 20
  min_connections: 5
  max_idle_time: 300s
  max_lifetime: 3600s

# Portfolio Service  
portfolio_service:
  max_connections: 30
  min_connections: 10
  max_idle_time: 300s
  max_lifetime: 3600s

# Analytics Service
analytics_service:
  max_connections: 40
  min_connections: 15
  max_idle_time: 600s
  max_lifetime: 3600s
```

### Redis Connection Pools

```yaml
# Per Service Configuration
redis_pool:
  max_connections: 50
  min_connections: 10
  max_idle_time: 120s
  timeout: 5s
  retry_attempts: 3
```

## Network Security

### Development Environment

```mermaid
graph TB
    subgraph "Docker Network: nexanest-db"
        PG[PostgreSQL<br/>Container]
        TS[TimescaleDB<br/>Container]
        REDIS[Redis<br/>Container]
        PGADMIN[PgAdmin<br/>Container]
    end
    
    subgraph "Docker Network: nexanest-app"
        AUTH[Auth Service]
        PORTFOLIO[Portfolio Service]
        MARKET[Market Service]
    end
    
    subgraph "Host Network"
        LOCALHOST[localhost]
    end
    
    %% Port mappings
    LOCALHOST -->|5432| PG
    LOCALHOST -->|5433| TS
    LOCALHOST -->|6379| REDIS
    LOCALHOST -->|5050| PGADMIN
    
    %% Internal service communication
    AUTH --> PG
    PORTFOLIO --> PG
    MARKET --> TS
    
    AUTH --> REDIS
    PORTFOLIO --> REDIS
    MARKET --> REDIS
```

### Production Environment

```mermaid
graph TB
    subgraph "Public Subnet"
        LB[Load Balancer]
        GATEWAY[API Gateway]
    end
    
    subgraph "Private Subnet - Application"
        AUTH[Auth Service]
        PORTFOLIO[Portfolio Service]
        MARKET[Market Service]
        ANALYTICS[Analytics Service]
    end
    
    subgraph "Private Subnet - Database"
        PG_MASTER[PostgreSQL Master]
        PG_REPLICA[PostgreSQL Replica]
        TS[TimescaleDB]
        REDIS[Redis Cluster]
    end
    
    subgraph "Management Subnet"
        BASTION[Bastion Host]
        PGADMIN[PgAdmin]
    end
    
    %% Public access
    INTERNET --> LB
    LB --> GATEWAY
    
    %% Application layer
    GATEWAY --> AUTH
    GATEWAY --> PORTFOLIO
    GATEWAY --> MARKET
    GATEWAY --> ANALYTICS
    
    %% Database access
    AUTH --> PG_MASTER
    PORTFOLIO --> PG_MASTER
    ANALYTICS --> PG_REPLICA
    
    MARKET --> TS
    PORTFOLIO --> TS
    
    AUTH --> REDIS
    PORTFOLIO --> REDIS
    MARKET --> REDIS
    
    %% Management access
    BASTION --> PG_MASTER
    BASTION --> TS
    BASTION --> REDIS
    PGADMIN --> PG_MASTER
    PGADMIN --> TS
```

## Environment Configuration

### Development (.env.db)
```bash
# Database Host Configuration
DB_HOST=pgdb.nn.local

# PostgreSQL
POSTGRES_HOST=${DB_HOST}
POSTGRES_PASSWORD=nexanest_dev_password
POSTGRES_USER=nexanest
POSTGRES_DB=nexanest

# TimescaleDB
TIMESCALE_HOST=${DB_HOST}
TIMESCALE_PASSWORD=timescale_dev_password
TIMESCALE_USER=timescale
TIMESCALE_DB=timescale

# Redis
REDIS_HOST=${DB_HOST}
REDIS_PASSWORD=redis_dev_password

# PgAdmin
PGADMIN_EMAIL=admin@nexanest.local
PGADMIN_PASSWORD=admin_dev_password
```

### Production Environment Variables
```bash
# PostgreSQL Cluster
POSTGRES_MASTER_HOST=postgres-master.nexanest.internal
POSTGRES_REPLICA_HOST=postgres-replica.nexanest.internal
POSTGRES_PASSWORD=${POSTGRES_PASSWORD_SECRET}
POSTGRES_SSL_MODE=require

# TimescaleDB
TIMESCALE_HOST=timescale.nexanest.internal
TIMESCALE_PASSWORD=${TIMESCALE_PASSWORD_SECRET}
TIMESCALE_SSL_MODE=require

# Redis Cluster
REDIS_CLUSTER_HOSTS=redis-1.nexanest.internal:6379,redis-2.nexanest.internal:6379,redis-3.nexanest.internal:6379
REDIS_PASSWORD=${REDIS_PASSWORD_SECRET}
REDIS_SSL=true
```

## Health Checks

### Database Health Check Endpoints

```yaml
# PostgreSQL Health Check
/health/postgres:
  query: "SELECT 1"
  timeout: 5s
  interval: 30s

# TimescaleDB Health Check  
/health/timescale:
  query: "SELECT 1 FROM pg_stat_activity LIMIT 1"
  timeout: 5s
  interval: 30s

# Redis Health Check
/health/redis:
  command: "PING"
  timeout: 3s
  interval: 15s
```

### Connection Monitoring

```sql
-- PostgreSQL Active Connections
SELECT datname, count(*) as connections
FROM pg_stat_activity 
WHERE state = 'active'
GROUP BY datname;

-- TimescaleDB Performance
SELECT schemaname, tablename, 
       pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
FROM pg_tables 
WHERE schemaname NOT IN ('information_schema', 'pg_catalog')
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
```

```bash
# Redis Connection Info
redis-cli INFO clients
redis-cli INFO memory
```

## Troubleshooting

### Common Connection Issues

1. **Connection Refused**
   ```bash
   # Check if services are running
   docker-compose ps
   
   # Check port availability
   netstat -tulpn | grep :5432
   ```

2. **Authentication Failed**
   ```bash
   # Verify environment variables
   cat .env.db
   
   # Test connection
   psql -h localhost -p 5432 -U nexanest -d auth
   ```

3. **Connection Pool Exhausted**
   ```sql
   -- Check active connections
   SELECT count(*) FROM pg_stat_activity WHERE state = 'active';
   
   -- Identify long-running queries
   SELECT pid, now() - pg_stat_activity.query_start AS duration, query 
   FROM pg_stat_activity 
   WHERE (now() - pg_stat_activity.query_start) > interval '5 minutes';
   ```

4. **Redis Connection Issues**
   ```bash
   # Test Redis connectivity
   redis-cli -h localhost -p 6379 ping
   
   # Check Redis memory usage
   redis-cli info memory
   ```

### Performance Monitoring

```sql
-- Slow queries (PostgreSQL)
SELECT query, mean_time, calls, total_time
FROM pg_stat_statements 
ORDER BY mean_time DESC 
LIMIT 10;

-- Database sizes
SELECT datname, pg_size_pretty(pg_database_size(datname)) as size
FROM pg_database 
ORDER BY pg_database_size(datname) DESC;
```

## Related Documentation

- [Database Host Setup - pgdb.nn.local](../infrastructure/database-host-setup.md)
- [Database Architecture](architecture.md)
- [Schema Documentation](schemas/index.md)
- [SSH Access Setup Guide](../infrastructure/ssh-access-setup.md)
- [ADR-015: Database Deployment Strategy](../architecture/adr-015-database-deployment-strategy.md)