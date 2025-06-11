-- Portfolio Service Database Schema
-- Database: portfolio
-- Schema: portfolio

\c portfolio;
SET search_path TO portfolio, public;
SET timezone = 'Australia/Adelaide';

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Portfolios table
CREATE TABLE portfolio.portfolios (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL, -- References auth.users(id)
    name VARCHAR(255) NOT NULL,
    description TEXT,
    currency VARCHAR(3) NOT NULL DEFAULT 'AUD',
    portfolio_type VARCHAR(50) NOT NULL DEFAULT 'INVESTMENT',
    risk_profile VARCHAR(20) DEFAULT 'MODERATE',
    target_allocation JSONB DEFAULT '{}',
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT valid_portfolio_type CHECK (portfolio_type IN ('INVESTMENT', 'RETIREMENT', 'SAVINGS', 'TRADING', 'EDUCATION')),
    CONSTRAINT valid_risk_profile CHECK (risk_profile IN ('CONSERVATIVE', 'MODERATE', 'AGGRESSIVE', 'CUSTOM')),
    CONSTRAINT valid_currency CHECK (currency ~ '^[A-Z]{3}$')
);

-- Holdings table - tracks individual positions
CREATE TABLE portfolio.holdings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    portfolio_id UUID NOT NULL REFERENCES portfolio.portfolios(id) ON DELETE CASCADE,
    symbol VARCHAR(20) NOT NULL,
    asset_type VARCHAR(20) NOT NULL DEFAULT 'STOCK',
    quantity DECIMAL(18,8) NOT NULL DEFAULT 0,
    average_cost DECIMAL(12,4) NOT NULL DEFAULT 0,
    current_price DECIMAL(12,4),
    market_value DECIMAL(15,2),
    unrealized_gain_loss DECIMAL(15,2),
    unrealized_gain_loss_percent DECIMAL(5,2),
    last_updated TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT valid_asset_type CHECK (asset_type IN ('STOCK', 'ETF', 'BOND', 'OPTION', 'FUTURE', 'CRYPTO', 'CASH', 'COMMODITY')),
    CONSTRAINT positive_quantity CHECK (quantity >= 0),
    CONSTRAINT positive_price CHECK (current_price >= 0),
    UNIQUE(portfolio_id, symbol)
);

-- Transactions table - tracks all buy/sell/dividend transactions
CREATE TABLE portfolio.transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    portfolio_id UUID NOT NULL REFERENCES portfolio.portfolios(id) ON DELETE CASCADE,
    holding_id UUID REFERENCES portfolio.holdings(id) ON DELETE SET NULL,
    symbol VARCHAR(20) NOT NULL,
    transaction_type VARCHAR(20) NOT NULL,
    quantity DECIMAL(18,8) NOT NULL,
    price DECIMAL(12,4) NOT NULL,
    total_amount DECIMAL(15,2) NOT NULL,
    fees DECIMAL(8,2) DEFAULT 0,
    tax DECIMAL(8,2) DEFAULT 0,
    currency VARCHAR(3) NOT NULL DEFAULT 'AUD',
    exchange_rate DECIMAL(10,6) DEFAULT 1.0,
    transaction_date TIMESTAMPTZ NOT NULL,
    settlement_date TIMESTAMPTZ,
    broker VARCHAR(100),
    order_id VARCHAR(100),
    notes TEXT,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT valid_transaction_type CHECK (transaction_type IN ('BUY', 'SELL', 'DIVIDEND', 'SPLIT', 'MERGER', 'SPINOFF', 'DEPOSIT', 'WITHDRAWAL', 'FEE', 'TAX')),
    CONSTRAINT valid_currency CHECK (currency ~ '^[A-Z]{3}$')
);

-- Portfolio snapshots for performance tracking
CREATE TABLE portfolio.portfolio_snapshots (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    portfolio_id UUID NOT NULL REFERENCES portfolio.portfolios(id) ON DELETE CASCADE,
    snapshot_date DATE NOT NULL,
    total_value DECIMAL(15,2) NOT NULL,
    cash_value DECIMAL(15,2) NOT NULL DEFAULT 0,
    invested_value DECIMAL(15,2) NOT NULL,
    total_cost_basis DECIMAL(15,2) NOT NULL,
    unrealized_gain_loss DECIMAL(15,2) DEFAULT 0,
    realized_gain_loss DECIMAL(15,2) DEFAULT 0,
    dividend_income DECIMAL(15,2) DEFAULT 0,
    fees_paid DECIMAL(8,2) DEFAULT 0,
    allocation JSONB DEFAULT '{}',
    holdings_count INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    UNIQUE(portfolio_id, snapshot_date)
);

-- Performance benchmarks
CREATE TABLE portfolio.benchmarks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL UNIQUE,
    symbol VARCHAR(20) NOT NULL UNIQUE,
    description TEXT,
    provider VARCHAR(50),
    currency VARCHAR(3) NOT NULL DEFAULT 'AUD',
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Portfolio benchmark relationships
CREATE TABLE portfolio.portfolio_benchmarks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    portfolio_id UUID NOT NULL REFERENCES portfolio.portfolios(id) ON DELETE CASCADE,
    benchmark_id UUID NOT NULL REFERENCES portfolio.benchmarks(id) ON DELETE CASCADE,
    weight DECIMAL(5,2) NOT NULL DEFAULT 100.00,
    is_primary BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT valid_weight CHECK (weight > 0 AND weight <= 100),
    UNIQUE(portfolio_id, benchmark_id)
);

-- Watchlists for tracking symbols of interest
CREATE TABLE portfolio.watchlists (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL, -- References auth.users(id)
    name VARCHAR(255) NOT NULL,
    description TEXT,
    is_public BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    UNIQUE(user_id, name)
);

-- Watchlist items
CREATE TABLE portfolio.watchlist_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    watchlist_id UUID NOT NULL REFERENCES portfolio.watchlists(id) ON DELETE CASCADE,
    symbol VARCHAR(20) NOT NULL,
    notes TEXT,
    price_alert_high DECIMAL(12,4),
    price_alert_low DECIMAL(12,4),
    added_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    UNIQUE(watchlist_id, symbol)
);

-- Goals and targets
CREATE TABLE portfolio.portfolio_goals (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    portfolio_id UUID NOT NULL REFERENCES portfolio.portfolios(id) ON DELETE CASCADE,
    goal_type VARCHAR(30) NOT NULL,
    target_value DECIMAL(15,2),
    target_date DATE,
    current_progress DECIMAL(5,2) DEFAULT 0,
    is_achieved BOOLEAN NOT NULL DEFAULT false,
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT valid_goal_type CHECK (goal_type IN ('RETIREMENT', 'HOUSE_DEPOSIT', 'VACATION', 'EDUCATION', 'EMERGENCY_FUND', 'GENERAL_WEALTH', 'CUSTOM'))
);

-- Asset allocations and rebalancing rules
CREATE TABLE portfolio.allocation_rules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    portfolio_id UUID NOT NULL REFERENCES portfolio.portfolios(id) ON DELETE CASCADE,
    asset_class VARCHAR(50) NOT NULL,
    target_percentage DECIMAL(5,2) NOT NULL,
    min_percentage DECIMAL(5,2),
    max_percentage DECIMAL(5,2),
    rebalance_threshold DECIMAL(5,2) DEFAULT 5.00,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT valid_percentages CHECK (
        target_percentage >= 0 AND target_percentage <= 100 AND
        (min_percentage IS NULL OR min_percentage >= 0) AND
        (max_percentage IS NULL OR max_percentage <= 100) AND
        (min_percentage IS NULL OR max_percentage IS NULL OR min_percentage <= max_percentage)
    ),
    UNIQUE(portfolio_id, asset_class)
);

-- Indexes for performance
CREATE INDEX idx_portfolios_user_id ON portfolio.portfolios(user_id);
CREATE INDEX idx_portfolios_active ON portfolio.portfolios(is_active);
CREATE INDEX idx_portfolios_type ON portfolio.portfolios(portfolio_type);

CREATE INDEX idx_holdings_portfolio_id ON portfolio.holdings(portfolio_id);
CREATE INDEX idx_holdings_symbol ON portfolio.holdings(symbol);
CREATE INDEX idx_holdings_asset_type ON portfolio.holdings(asset_type);
CREATE INDEX idx_holdings_updated ON portfolio.holdings(last_updated);

CREATE INDEX idx_transactions_portfolio_id ON portfolio.transactions(portfolio_id);
CREATE INDEX idx_transactions_holding_id ON portfolio.transactions(holding_id);
CREATE INDEX idx_transactions_symbol ON portfolio.transactions(symbol);
CREATE INDEX idx_transactions_type ON portfolio.transactions(transaction_type);
CREATE INDEX idx_transactions_date ON portfolio.transactions(transaction_date);
CREATE INDEX idx_transactions_settlement ON portfolio.transactions(settlement_date);

CREATE INDEX idx_snapshots_portfolio_id ON portfolio.portfolio_snapshots(portfolio_id);
CREATE INDEX idx_snapshots_date ON portfolio.portfolio_snapshots(snapshot_date);

CREATE INDEX idx_watchlists_user_id ON portfolio.watchlists(user_id);
CREATE INDEX idx_watchlist_items_symbol ON portfolio.watchlist_items(symbol);

CREATE INDEX idx_goals_portfolio_id ON portfolio.portfolio_goals(portfolio_id);
CREATE INDEX idx_goals_type ON portfolio.portfolio_goals(goal_type);
CREATE INDEX idx_goals_target_date ON portfolio.portfolio_goals(target_date);

-- Triggers for updated_at timestamps
CREATE OR REPLACE FUNCTION portfolio.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_portfolios_updated_at 
    BEFORE UPDATE ON portfolio.portfolios 
    FOR EACH ROW EXECUTE FUNCTION portfolio.update_updated_at_column();

CREATE TRIGGER update_holdings_updated_at 
    BEFORE UPDATE ON portfolio.holdings 
    FOR EACH ROW EXECUTE FUNCTION portfolio.update_updated_at_column();

CREATE TRIGGER update_watchlists_updated_at 
    BEFORE UPDATE ON portfolio.watchlists 
    FOR EACH ROW EXECUTE FUNCTION portfolio.update_updated_at_column();

CREATE TRIGGER update_goals_updated_at 
    BEFORE UPDATE ON portfolio.portfolio_goals 
    FOR EACH ROW EXECUTE FUNCTION portfolio.update_updated_at_column();

CREATE TRIGGER update_allocation_rules_updated_at 
    BEFORE UPDATE ON portfolio.allocation_rules 
    FOR EACH ROW EXECUTE FUNCTION portfolio.update_updated_at_column();

-- Function to calculate portfolio value
CREATE OR REPLACE FUNCTION portfolio.calculate_portfolio_value(p_portfolio_id UUID)
RETURNS DECIMAL(15,2) AS $$
DECLARE
    total_value DECIMAL(15,2) := 0;
BEGIN
    SELECT COALESCE(SUM(market_value), 0) 
    INTO total_value
    FROM portfolio.holdings 
    WHERE portfolio_id = p_portfolio_id;
    
    RETURN total_value;
END;
$$ LANGUAGE plpgsql;

-- Function to update holding market values
CREATE OR REPLACE FUNCTION portfolio.update_holding_market_value()
RETURNS TRIGGER AS $$
BEGIN
    NEW.market_value = NEW.quantity * COALESCE(NEW.current_price, NEW.average_cost);
    NEW.unrealized_gain_loss = NEW.market_value - (NEW.quantity * NEW.average_cost);
    
    IF NEW.quantity * NEW.average_cost > 0 THEN
        NEW.unrealized_gain_loss_percent = (NEW.unrealized_gain_loss / (NEW.quantity * NEW.average_cost)) * 100;
    ELSE
        NEW.unrealized_gain_loss_percent = 0;
    END IF;
    
    NEW.last_updated = NOW();
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER calculate_holding_values 
    BEFORE INSERT OR UPDATE ON portfolio.holdings 
    FOR EACH ROW EXECUTE FUNCTION portfolio.update_holding_market_value();

-- Row Level Security
ALTER TABLE portfolio.portfolios ENABLE ROW LEVEL SECURITY;
ALTER TABLE portfolio.holdings ENABLE ROW LEVEL SECURITY;
ALTER TABLE portfolio.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE portfolio.portfolio_snapshots ENABLE ROW LEVEL SECURITY;
ALTER TABLE portfolio.watchlists ENABLE ROW LEVEL SECURITY;
ALTER TABLE portfolio.watchlist_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE portfolio.portfolio_goals ENABLE ROW LEVEL SECURITY;

-- Users can only access their own portfolios and related data
CREATE POLICY user_own_portfolios ON portfolio.portfolios 
    FOR ALL TO authenticated 
    USING (user_id = current_setting('app.current_user_id')::UUID);

CREATE POLICY user_portfolio_holdings ON portfolio.holdings 
    FOR ALL TO authenticated 
    USING (portfolio_id IN (
        SELECT id FROM portfolio.portfolios 
        WHERE user_id = current_setting('app.current_user_id')::UUID
    ));

CREATE POLICY user_portfolio_transactions ON portfolio.transactions 
    FOR ALL TO authenticated 
    USING (portfolio_id IN (
        SELECT id FROM portfolio.portfolios 
        WHERE user_id = current_setting('app.current_user_id')::UUID
    ));

CREATE POLICY user_portfolio_snapshots ON portfolio.portfolio_snapshots 
    FOR ALL TO authenticated 
    USING (portfolio_id IN (
        SELECT id FROM portfolio.portfolios 
        WHERE user_id = current_setting('app.current_user_id')::UUID
    ));

CREATE POLICY user_own_watchlists ON portfolio.watchlists 
    FOR ALL TO authenticated 
    USING (user_id = current_setting('app.current_user_id')::UUID OR is_public = true);

CREATE POLICY user_watchlist_items ON portfolio.watchlist_items 
    FOR ALL TO authenticated 
    USING (watchlist_id IN (
        SELECT id FROM portfolio.watchlists 
        WHERE user_id = current_setting('app.current_user_id')::UUID OR is_public = true
    ));

CREATE POLICY user_portfolio_goals ON portfolio.portfolio_goals 
    FOR ALL TO authenticated 
    USING (portfolio_id IN (
        SELECT id FROM portfolio.portfolios 
        WHERE user_id = current_setting('app.current_user_id')::UUID
    ));

-- Create application roles
CREATE ROLE portfolio_service_write;
CREATE ROLE portfolio_service_read;

-- Grant permissions
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA portfolio TO portfolio_service_write;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA portfolio TO portfolio_service_write;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA portfolio TO portfolio_service_write;

GRANT SELECT ON ALL TABLES IN SCHEMA portfolio TO portfolio_service_read;

-- Insert default benchmarks
INSERT INTO portfolio.benchmarks (name, symbol, description, provider, currency) VALUES
    ('All Ordinaries', 'XAO', 'Australian All Ordinaries Index', 'ASX', 'AUD'),
    ('ASX 200', 'XJO', 'S&P/ASX 200 Index', 'ASX', 'AUD'),
    ('ASX Small Ordinaries', 'XSO', 'S&P/ASX Small Ordinaries Index', 'ASX', 'AUD'),
    ('S&P 500', 'SPX', 'S&P 500 Index', 'S&P', 'USD'),
    ('NASDAQ Composite', 'IXIC', 'NASDAQ Composite Index', 'NASDAQ', 'USD'),
    ('FTSE 100', 'UKX', 'FTSE 100 Index', 'FTSE', 'GBP'),
    ('Nikkei 225', 'NKY', 'Nikkei 225 Index', 'Nikkei', 'JPY');

-- Log schema creation
DO $$
BEGIN
    RAISE NOTICE 'Portfolio service database schema created successfully';
    RAISE NOTICE 'Default benchmarks created for major market indices';
    RAISE NOTICE 'Row-level security enabled for multi-tenant data isolation';
END $$;