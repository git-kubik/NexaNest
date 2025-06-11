-- NexaNest Database Initialization Script
-- Creates separate databases for each microservice
-- 
-- This script runs when PostgreSQL container starts for the first time
-- It creates individual databases for each service following microservices best practices

-- Set timezone for all operations
SET timezone = 'Australia/Adelaide';

-- Create databases for each microservice
CREATE DATABASE auth WITH 
    OWNER = nexanest 
    ENCODING = 'UTF8' 
    LC_COLLATE = 'en_US.utf8' 
    LC_CTYPE = 'en_US.utf8' 
    TEMPLATE = template0;

CREATE DATABASE portfolio WITH 
    OWNER = nexanest 
    ENCODING = 'UTF8' 
    LC_COLLATE = 'en_US.utf8' 
    LC_CTYPE = 'en_US.utf8' 
    TEMPLATE = template0;

CREATE DATABASE analytics WITH 
    OWNER = nexanest 
    ENCODING = 'UTF8' 
    LC_COLLATE = 'en_US.utf8' 
    LC_CTYPE = 'en_US.utf8' 
    TEMPLATE = template0;

CREATE DATABASE notifications WITH 
    OWNER = nexanest 
    ENCODING = 'UTF8' 
    LC_COLLATE = 'en_US.utf8' 
    LC_CTYPE = 'en_US.utf8' 
    TEMPLATE = template0;

-- Grant all privileges to nexanest user on all databases
GRANT ALL PRIVILEGES ON DATABASE auth TO nexanest;
GRANT ALL PRIVILEGES ON DATABASE portfolio TO nexanest;
GRANT ALL PRIVILEGES ON DATABASE analytics TO nexanest;
GRANT ALL PRIVILEGES ON DATABASE notifications TO nexanest;

-- Connect to each database and set up extensions and schemas
\c auth;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Create auth database schema
CREATE SCHEMA IF NOT EXISTS auth AUTHORIZATION nexanest;
SET search_path TO auth, public;

\c portfolio;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Create portfolio database schema
CREATE SCHEMA IF NOT EXISTS portfolio AUTHORIZATION nexanest;
SET search_path TO portfolio, public;

\c analytics;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Create analytics database schema
CREATE SCHEMA IF NOT EXISTS analytics AUTHORIZATION nexanest;
SET search_path TO analytics, public;

\c notifications;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Create notifications database schema
CREATE SCHEMA IF NOT EXISTS notifications AUTHORIZATION nexanest;
SET search_path TO notifications, public;

-- Return to main database
\c nexanest;

-- Log the completion
INSERT INTO pg_stat_statements_reset();

-- Display created databases
SELECT datname, datowner, encoding, datcollate, datctype 
FROM pg_database 
WHERE datname IN ('auth', 'portfolio', 'analytics', 'notifications')
ORDER BY datname;