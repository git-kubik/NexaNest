#!/bin/bash
# NexaNest Quick Start Script

set -e

echo "🚀 NexaNest Quick Start"
echo "======================"

# Check prerequisites
check_command() {
    if ! command -v $1 &> /dev/null; then
        echo "❌ $1 is not installed. Please install it first."
        exit 1
    fi
}

echo "Checking prerequisites..."
check_command docker
check_command docker-compose
echo "✅ All prerequisites met"

# Create .env if it doesn't exist
if [ ! -f .env ]; then
    echo "Creating .env file..."
    cp .env.example .env
    echo "⚠️  Please edit .env file with your configuration"
fi

# Start infrastructure services
echo "Starting infrastructure services..."
docker-compose up -d postgres timescaledb redis kafka zookeeper opensearch

# Wait for services to be ready
echo "Waiting for services to be ready..."
sleep 15

# Check service health
echo "Checking service health..."
docker-compose ps

echo ""
echo "✅ Infrastructure services are running!"
echo ""
echo "Service URLs:"
echo "  PostgreSQL:    localhost:5432"
echo "  TimescaleDB:   localhost:5433"
echo "  Redis:         localhost:6379"
echo "  Kafka:         localhost:9092"
echo "  OpenSearch:    localhost:9200"
echo ""
echo "Next steps:"
echo "1. Install Python dependencies:"
echo "   cd services/auth && pip install -e ."
echo ""
echo "2. Run database migrations:"
echo "   cd services/auth && alembic upgrade head"
echo ""
echo "3. Start the auth service:"
echo "   cd services/auth && python -m app.main"
echo ""
echo "4. Access API documentation:"
echo "   http://localhost:8001/docs"
echo ""
echo "Happy coding! 🎉"