-- TimescaleDB Initialization Script for NexaNest
-- Sets up time-series databases for market data and analytics
--
-- This script runs when TimescaleDB container starts for the first time

-- Set timezone
SET timezone = 'Australia/Adelaide';

-- Create TimescaleDB extension
CREATE EXTENSION IF NOT EXISTS timescaledb;

-- Create schemas for different data types
CREATE SCHEMA IF NOT EXISTS market_data AUTHORIZATION timescale;
CREATE SCHEMA IF NOT EXISTS analytics_ts AUTHORIZATION timescale;
CREATE SCHEMA IF NOT EXISTS events AUTHORIZATION timescale;

-- Set search path
SET search_path TO market_data, analytics_ts, events, public;

-- Market Data Tables

-- Stock prices table (hypertable for time-series data)
CREATE TABLE market_data.stock_prices (
    time TIMESTAMPTZ NOT NULL,
    symbol VARCHAR(20) NOT NULL,
    price DECIMAL(12,4) NOT NULL,
    volume BIGINT,
    market_cap DECIMAL(20,2),
    exchange VARCHAR(10),
    currency VARCHAR(3) DEFAULT 'AUD',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create hypertable for stock prices
SELECT create_hypertable('market_data.stock_prices', 'time');

-- Create indexes for efficient queries
CREATE INDEX idx_stock_prices_symbol_time ON market_data.stock_prices (symbol, time DESC);
CREATE INDEX idx_stock_prices_exchange ON market_data.stock_prices (exchange, time DESC);

-- Market indices table
CREATE TABLE market_data.market_indices (
    time TIMESTAMPTZ NOT NULL,
    index_name VARCHAR(50) NOT NULL,
    value DECIMAL(12,4) NOT NULL,
    change_percent DECIMAL(5,2),
    exchange VARCHAR(10),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create hypertable for market indices
SELECT create_hypertable('market_data.market_indices', 'time');

-- Currency exchange rates
CREATE TABLE market_data.currency_rates (
    time TIMESTAMPTZ NOT NULL,
    from_currency VARCHAR(3) NOT NULL,
    to_currency VARCHAR(3) NOT NULL,
    rate DECIMAL(12,6) NOT NULL,
    provider VARCHAR(50),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create hypertable for currency rates
SELECT create_hypertable('market_data.currency_rates', 'time');

-- Analytics Time-Series Tables

-- Portfolio performance snapshots
CREATE TABLE analytics_ts.portfolio_snapshots (
    time TIMESTAMPTZ NOT NULL,
    portfolio_id UUID NOT NULL,
    total_value DECIMAL(15,2) NOT NULL,
    cash_value DECIMAL(15,2) NOT NULL,
    invested_value DECIMAL(15,2) NOT NULL,
    day_change DECIMAL(15,2),
    day_change_percent DECIMAL(5,2),
    total_return DECIMAL(15,2),
    total_return_percent DECIMAL(5,2),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create hypertable for portfolio snapshots
SELECT create_hypertable('analytics_ts.portfolio_snapshots', 'time');

-- Risk metrics over time
CREATE TABLE analytics_ts.risk_metrics (
    time TIMESTAMPTZ NOT NULL,
    portfolio_id UUID NOT NULL,
    var_1d DECIMAL(15,2),
    var_1w DECIMAL(15,2),
    var_1m DECIMAL(15,2),
    beta DECIMAL(6,3),
    sharpe_ratio DECIMAL(6,3),
    volatility DECIMAL(6,3),
    max_drawdown DECIMAL(5,2),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create hypertable for risk metrics
SELECT create_hypertable('analytics_ts.risk_metrics', 'time');

-- Event Logging Tables

-- System events and audit trail
CREATE TABLE events.system_events (
    time TIMESTAMPTZ NOT NULL,
    event_type VARCHAR(50) NOT NULL,
    service_name VARCHAR(50) NOT NULL,
    user_id UUID,
    event_data JSONB,
    severity VARCHAR(20) DEFAULT 'INFO',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create hypertable for system events
SELECT create_hypertable('events.system_events', 'time');

-- Trading events
CREATE TABLE events.trading_events (
    time TIMESTAMPTZ NOT NULL,
    portfolio_id UUID NOT NULL,
    symbol VARCHAR(20) NOT NULL,
    event_type VARCHAR(30) NOT NULL, -- BUY, SELL, DIVIDEND, SPLIT, etc.
    quantity DECIMAL(15,4),
    price DECIMAL(12,4),
    value DECIMAL(15,2),
    fees DECIMAL(8,2),
    metadata JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create hypertable for trading events
SELECT create_hypertable('events.trading_events', 'time');

-- Create retention policies (automatically delete old data)
-- Keep market data for 2 years
SELECT add_retention_policy('market_data.stock_prices', INTERVAL '2 years');
SELECT add_retention_policy('market_data.market_indices', INTERVAL '2 years');
SELECT add_retention_policy('market_data.currency_rates', INTERVAL '2 years');

-- Keep analytics data for 5 years
SELECT add_retention_policy('analytics_ts.portfolio_snapshots', INTERVAL '5 years');
SELECT add_retention_policy('analytics_ts.risk_metrics', INTERVAL '5 years');

-- Keep event logs for 1 year
SELECT add_retention_policy('events.system_events', INTERVAL '1 year');
SELECT add_retention_policy('events.trading_events', INTERVAL '7 years'); -- Keep trading history longer for tax purposes

-- Create continuous aggregates for common queries
-- Daily market data aggregates
CREATE MATERIALIZED VIEW market_data.daily_stock_prices
WITH (timescaledb.continuous) AS
SELECT time_bucket('1 day', time) AS bucket,
       symbol,
       first(price, time) AS open_price,
       max(price) AS high_price,
       min(price) AS low_price,
       last(price, time) AS close_price,
       sum(volume) AS total_volume,
       avg(price) AS avg_price
FROM market_data.stock_prices
GROUP BY bucket, symbol
WITH NO DATA;

-- Enable automatic refresh for the continuous aggregate
SELECT add_continuous_aggregate_policy('market_data.daily_stock_prices',
    start_offset => INTERVAL '7 days',
    end_offset => INTERVAL '1 hour',
    schedule_interval => INTERVAL '1 hour');

-- Weekly portfolio performance aggregates
CREATE MATERIALIZED VIEW analytics_ts.weekly_portfolio_performance
WITH (timescaledb.continuous) AS
SELECT time_bucket('1 week', time) AS bucket,
       portfolio_id,
       avg(total_value) AS avg_value,
       first(total_value, time) AS start_value,
       last(total_value, time) AS end_value,
       max(total_value) AS max_value,
       min(total_value) AS min_value,
       sum(day_change) AS total_change
FROM analytics_ts.portfolio_snapshots
GROUP BY bucket, portfolio_id
WITH NO DATA;

-- Enable automatic refresh
SELECT add_continuous_aggregate_policy('analytics_ts.weekly_portfolio_performance',
    start_offset => INTERVAL '1 month',
    end_offset => INTERVAL '1 day',
    schedule_interval => INTERVAL '1 day');

-- Grant permissions
GRANT USAGE ON SCHEMA market_data TO timescale;
GRANT USAGE ON SCHEMA analytics_ts TO timescale;
GRANT USAGE ON SCHEMA events TO timescale;

GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA market_data TO timescale;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA analytics_ts TO timescale;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA events TO timescale;

-- Display setup summary
SELECT 'TimescaleDB setup completed successfully' AS status;