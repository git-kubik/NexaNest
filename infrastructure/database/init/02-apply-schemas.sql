-- Apply all service schemas to their respective databases
-- This script runs after the databases are created

-- Apply auth service schema
\echo 'Applying auth service schema...'
\i '/docker-entrypoint-initdb.d/schemas/auth-schema.sql'

-- Apply portfolio service schema  
\echo 'Applying portfolio service schema...'
\i '/docker-entrypoint-initdb.d/schemas/portfolio-schema.sql'

-- Note: Analytics and notifications schemas will be created when those services are implemented

\echo 'All schemas applied successfully!'