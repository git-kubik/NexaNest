-- Authentication Service Database Schema
-- Database: auth
-- Schema: auth

\c auth;
SET search_path TO auth, public;
SET timezone = 'Australia/Adelaide';

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Users table
CREATE TABLE auth.users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    username VARCHAR(100) UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    role VARCHAR(20) NOT NULL DEFAULT 'USER',
    is_active BOOLEAN NOT NULL DEFAULT true,
    is_verified BOOLEAN NOT NULL DEFAULT false,
    last_login TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT valid_role CHECK (role IN ('USER', 'ADVISOR', 'ADMIN', 'SUPERUSER')),
    CONSTRAINT valid_email CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
);

-- User profiles table
CREATE TABLE auth.user_profiles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    phone VARCHAR(20),
    date_of_birth DATE,
    country VARCHAR(3), -- ISO 3166-1 alpha-3
    timezone VARCHAR(50) DEFAULT 'Australia/Adelaide',
    preferred_currency VARCHAR(3) DEFAULT 'AUD',
    avatar_url TEXT,
    bio TEXT,
    settings JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    UNIQUE(user_id)
);

-- Refresh tokens table
CREATE TABLE auth.refresh_tokens (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    token_hash VARCHAR(255) NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    is_revoked BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_used TIMESTAMPTZ,
    user_agent TEXT,
    ip_address INET,
    
    UNIQUE(token_hash)
);

-- API keys table for service-to-service authentication
CREATE TABLE auth.api_keys (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    service_name VARCHAR(100) NOT NULL,
    key_hash VARCHAR(255) NOT NULL,
    name VARCHAR(100) NOT NULL,
    permissions JSONB DEFAULT '[]',
    is_active BOOLEAN NOT NULL DEFAULT true,
    expires_at TIMESTAMPTZ,
    last_used TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    UNIQUE(key_hash),
    UNIQUE(user_id, name)
);

-- Password reset tokens
CREATE TABLE auth.password_reset_tokens (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    token_hash VARCHAR(255) NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    is_used BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    UNIQUE(token_hash)
);

-- Email verification tokens
CREATE TABLE auth.email_verification_tokens (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    token_hash VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    is_used BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    UNIQUE(token_hash)
);

-- Login attempts for rate limiting
CREATE TABLE auth.login_attempts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255),
    ip_address INET NOT NULL,
    user_agent TEXT,
    success BOOLEAN NOT NULL,
    failure_reason VARCHAR(100),
    attempted_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- User sessions for tracking active sessions
CREATE TABLE auth.user_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    session_token VARCHAR(255) NOT NULL,
    ip_address INET,
    user_agent TEXT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_activity TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    UNIQUE(session_token)
);

-- Indexes for performance
CREATE INDEX idx_users_email ON auth.users(email);
CREATE INDEX idx_users_username ON auth.users(username);
CREATE INDEX idx_users_role ON auth.users(role);
CREATE INDEX idx_users_active ON auth.users(is_active);
CREATE INDEX idx_users_created_at ON auth.users(created_at);

CREATE INDEX idx_refresh_tokens_user_id ON auth.refresh_tokens(user_id);
CREATE INDEX idx_refresh_tokens_expires_at ON auth.refresh_tokens(expires_at);
CREATE INDEX idx_refresh_tokens_revoked ON auth.refresh_tokens(is_revoked);

CREATE INDEX idx_api_keys_user_id ON auth.api_keys(user_id);
CREATE INDEX idx_api_keys_service ON auth.api_keys(service_name);
CREATE INDEX idx_api_keys_active ON auth.api_keys(is_active);

CREATE INDEX idx_login_attempts_email ON auth.login_attempts(email);
CREATE INDEX idx_login_attempts_ip ON auth.login_attempts(ip_address);
CREATE INDEX idx_login_attempts_attempted_at ON auth.login_attempts(attempted_at);

CREATE INDEX idx_user_sessions_user_id ON auth.user_sessions(user_id);
CREATE INDEX idx_user_sessions_active ON auth.user_sessions(is_active);
CREATE INDEX idx_user_sessions_expires_at ON auth.user_sessions(expires_at);

-- Triggers for updated_at timestamps
CREATE OR REPLACE FUNCTION auth.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_users_updated_at 
    BEFORE UPDATE ON auth.users 
    FOR EACH ROW EXECUTE FUNCTION auth.update_updated_at_column();

CREATE TRIGGER update_user_profiles_updated_at 
    BEFORE UPDATE ON auth.user_profiles 
    FOR EACH ROW EXECUTE FUNCTION auth.update_updated_at_column();

-- Function to clean up expired tokens
CREATE OR REPLACE FUNCTION auth.cleanup_expired_tokens()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER := 0;
BEGIN
    -- Delete expired refresh tokens
    DELETE FROM auth.refresh_tokens WHERE expires_at < NOW();
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    
    -- Delete expired password reset tokens
    DELETE FROM auth.password_reset_tokens WHERE expires_at < NOW();
    
    -- Delete expired email verification tokens
    DELETE FROM auth.email_verification_tokens WHERE expires_at < NOW();
    
    -- Delete old login attempts (keep only last 30 days)
    DELETE FROM auth.login_attempts WHERE attempted_at < NOW() - INTERVAL '30 days';
    
    -- Delete expired sessions
    DELETE FROM auth.user_sessions WHERE expires_at < NOW();
    
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- Row Level Security policies
ALTER TABLE auth.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE auth.user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE auth.refresh_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE auth.user_sessions ENABLE ROW LEVEL SECURITY;

-- Users can only see their own data
CREATE POLICY user_own_data ON auth.users 
    FOR ALL TO authenticated 
    USING (id = current_setting('app.current_user_id')::UUID);

CREATE POLICY user_own_profile ON auth.user_profiles 
    FOR ALL TO authenticated 
    USING (user_id = current_setting('app.current_user_id')::UUID);

CREATE POLICY user_own_tokens ON auth.refresh_tokens 
    FOR ALL TO authenticated 
    USING (user_id = current_setting('app.current_user_id')::UUID);

CREATE POLICY user_own_sessions ON auth.user_sessions 
    FOR ALL TO authenticated 
    USING (user_id = current_setting('app.current_user_id')::UUID);

-- Create application roles
CREATE ROLE auth_service;
CREATE ROLE portfolio_service;
CREATE ROLE analytics_service;
CREATE ROLE notification_service;

-- Grant permissions to auth service
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA auth TO auth_service;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA auth TO auth_service;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA auth TO auth_service;

-- Grant limited permissions to other services
GRANT SELECT ON auth.users TO portfolio_service;
GRANT SELECT ON auth.user_profiles TO portfolio_service;

GRANT SELECT ON auth.users TO analytics_service;
GRANT SELECT ON auth.user_profiles TO analytics_service;

GRANT SELECT ON auth.users TO notification_service;
GRANT SELECT ON auth.user_profiles TO notification_service;

-- Insert default admin user (password: admin123)
INSERT INTO auth.users (email, username, password_hash, first_name, last_name, role, is_active, is_verified)
VALUES (
    'admin@nexanest.local',
    'admin',
    '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBPj90Q3Ku7CIy', -- admin123
    'System',
    'Administrator',
    'SUPERUSER',
    true,
    true
);

-- Insert default test user (password: test123)
INSERT INTO auth.users (email, username, password_hash, first_name, last_name, role, is_active, is_verified)
VALUES (
    'test@nexanest.local',
    'testuser',
    '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeG6Lruj3vjPGga31lW', -- test123
    'Test',
    'User',
    'USER',
    true,
    true
);

-- Create corresponding profiles
INSERT INTO auth.user_profiles (user_id, timezone, preferred_currency)
SELECT id, 'Australia/Adelaide', 'AUD' FROM auth.users WHERE email IN ('admin@nexanest.local', 'test@nexanest.local');

-- Log schema creation
DO $$
BEGIN
    RAISE NOTICE 'Auth service database schema created successfully';
    RAISE NOTICE 'Default users created: admin@nexanest.local (SUPERUSER), test@nexanest.local (USER)';
    RAISE NOTICE 'Default password for both users: admin123 and test123 respectively';
END $$;