.PHONY: help dev stop clean test lint format setup

# Default target
help:
	@echo "NexaNest Development Commands:"
	@echo ""
	@echo "Development:"
	@echo "  make setup           - Initial project setup"
	@echo "  make install         - Install Python dependencies with uv"
	@echo "  make dev             - Start development environment"
	@echo "  make test            - Run all tests"
	@echo "  make lint            - Run code linters"
	@echo "  make format          - Format code"
	@echo ""
	@echo "Documentation:"
	@echo "  make docs-serve      - Serve documentation locally"
	@echo "  make docs-build      - Build documentation"
	@echo "  make docs-lint       - Lint documentation (full)"
	@echo "  make docs-lint-simple - Lint documentation (simple)"
	@echo ""
	@echo "Docker & Deployment:"
	@echo "  make setup-registry  - Setup local Docker registry"
	@echo "  make build-images    - Build and push Docker images"
	@echo "  make deploy-swarm    - Deploy to Docker Swarm"
	@echo "  make swarm-ps        - Show Swarm services"
	@echo ""
	@echo "Utilities:"
	@echo "  make stop            - Stop all services"
	@echo "  make clean           - Clean up containers and volumes"
	@echo "  make logs            - Show logs for all services"
	@echo "  make ps              - Show running services"
	@echo "  make health          - Check service health"

# Setup development environment
setup:
	@echo "Setting up NexaNest development environment..."
	@echo "Installing Python dependencies..."
	@cd services/auth && pip install -e .
	@cd services/portfolio && pip install -e .
	@cd services/ai-ml && pip install -e .
	@cd services/analytics && pip install -e .
	@echo "Setting up frontend..."
	@cd frontend && npm install
	@echo "Creating .env files..."
	@cp .env.example .env || true
	@echo "Setup complete!"

# Start development environment
dev:
	@echo "Starting NexaNest development environment..."
	docker-compose up -d postgres timescaledb redis kafka zookeeper opensearch
	@echo "Waiting for services to be ready..."
	@sleep 10
	@echo "Services started. Access:"
	@echo "  - PostgreSQL: localhost:5432"
	@echo "  - TimescaleDB: localhost:5433"
	@echo "  - Redis: localhost:6379"
	@echo "  - Kafka: localhost:9092"
	@echo "  - OpenSearch: localhost:9200"

# Stop all services
stop:
	docker-compose down

# Clean up everything
clean:
	docker-compose down -v
	rm -rf node_modules
	find . -type d -name "__pycache__" -exec rm -rf {} + || true
	find . -type d -name "*.egg-info" -exec rm -rf {} + || true
	find . -type d -name ".pytest_cache" -exec rm -rf {} + || true
	find . -type d -name ".coverage" -exec rm -rf {} + || true

# Run tests
test:
	@echo "Running tests..."
	@cd services/auth && pytest || true
	@cd services/portfolio && pytest || true
	@cd services/ai-ml && pytest || true
	@cd services/analytics && pytest || true
	@cd frontend && npm test || true

# Run linters
lint:
	@echo "Running linters..."
	@cd services/auth && ruff check . || true
	@cd services/portfolio && ruff check . || true
	@cd services/ai-ml && ruff check . || true
	@cd services/analytics && ruff check . || true
	@cd frontend && npm run lint || true

# Format code
format:
	@echo "Formatting code..."
	@cd services/auth && ruff format . || true
	@cd services/portfolio && ruff format . || true
	@cd services/ai-ml && ruff format . || true
	@cd services/analytics && ruff format . || true
	@cd frontend && npm run format || true

# Show logs
logs:
	docker-compose logs -f

# Show running services
ps:
	docker-compose ps

# Database migrations
migrate:
	@echo "Running database migrations..."
	@cd services/auth && alembic upgrade head || true
	@cd services/portfolio && alembic upgrade head || true

# Create new migration
migration:
	@echo "Creating new migration..."
	@read -p "Service (auth/portfolio): " service; \
	read -p "Migration message: " message; \
	cd services/$$service && alembic revision --autogenerate -m "$$message"

# Start specific service
service:
	@read -p "Service name (auth/portfolio/market-data/ai-ml/analytics/notification): " service; \
	cd services/$$service && python main.py

# Build Docker images
build:
	@echo "Building Docker images..."
	docker-compose build

# Run in production mode
prod:
	docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d

# Health check
health:
	@echo "Checking service health..."
	@curl -f http://localhost:8000/health || echo "API Gateway not healthy"
	@curl -f http://localhost:9200/_cluster/health || echo "OpenSearch not healthy"
	@redis-cli ping || echo "Redis not healthy"

# Documentation tasks
docs-serve:
	@echo "Starting documentation server..."
	mkdocs serve

docs-build:
	@echo "Building documentation..."
	mkdocs build

docs-lint:
	@echo "Linting documentation..."
	@command -v uv >/dev/null 2>&1 || pip install uv
	@./scripts/lint-docs.sh

docs-lint-simple:
	@echo "Simple documentation linting..."
	@./scripts/lint-docs-simple.sh

# Docker registry setup
setup-registry:
	@echo "Setting up local Docker registry..."
	@./scripts/setup-registry.sh

# Build and push images to local registry
build-images:
	@echo "Building and pushing images..."
	@./scripts/build-and-push.sh

# Deploy to Docker Swarm
deploy-swarm:
	@echo "Deploying to Docker Swarm..."
	docker stack deploy -c docker-compose.swarm.yml nexanest

# Show Swarm services
swarm-ps:
	docker service ls
	@echo ""
	docker stack ps nexanest

# Update Swarm services
swarm-update:
	@echo "Updating Swarm services..."
	docker service update --force nexanest_auth-service
	docker service update --force nexanest_portfolio-service

# Install Python dependencies with uv
install:
	@echo "Installing Python dependencies with uv..."
	@command -v uv >/dev/null 2>&1 || pip install uv
	uv pip install --system -e .
	@cd services/auth && uv pip install --system -e .
	@cd services/portfolio && uv pip install --system -e . || true