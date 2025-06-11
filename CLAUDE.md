# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

NexaNest v2.0 is a next-generation investment portfolio management platform that democratizes
institutional-grade financial analytics through AI. The project is being actively developed with a
microservices architecture.

## Project Structure

```text
nexanest/
├── docs/                    # Architecture and planning documents
├── services/                # Microservices
│   ├── auth/                # Authentication service (Python/FastAPI)
│   ├── portfolio/           # Portfolio management service
│   ├── market-data/         # Real-time market data service
│   ├── ai-ml/               # AI/ML service for insights
│   ├── analytics/           # Analytics and reporting engine
│   └── notification/        # Notification service
├── frontend/                # React 18 + TypeScript application
├── infrastructure/          # Terraform and Kubernetes configs
├── scripts/                 # Utility scripts
└── shared/                  # Shared libraries and utilities
```

## Architecture Goals

The system is designed to be:

- **Microservices-based** with domain-driven design
- **Cloud-native** with horizontal scalability
- **AI-powered** with support for multiple LLM providers
- **Real-time capable** with \<500ms data update latency
- **Secure** targeting SOC 2 Type II compliance

## Key Technical Requirements

### Performance Targets

- API response time < 100ms (p95)
- Dashboard initial load < 2 seconds
- Support for 10,000+ concurrent users
- 99.9% uptime SLA

### Core Capabilities

1. Multi-portfolio management with real-time tracking
1. AI-powered analysis and recommendations
1. Real-time market data integration
1. Risk assessment and optimization
1. Collaborative features for advisors/clients

## Development Guidelines

When implementing features:

- Follow API-first design principles
- Implement with test-driven development (minimum 80% coverage)
- Design for cloud deployment from the start
- Use Infrastructure as Code (IaC) practices
- Create Architecture Decision Records (ADRs) for key decisions
- Consider operational costs in all design decisions

## Common Development Tasks

### Quick Start

```bash
# Install dependencies with uv
make install

# Set up environment and secrets (first time only)
./scripts/setup-secrets.sh

# Start development environment
make dev

# Run all tests
make test

# Run linters
make lint

# Format code
make format

# View logs
make logs
```

### Service Development

```bash
# Start specific service (e.g., auth service)
cd services/auth
uv pip install --system -e .
python -m app.main

# Run service tests
cd services/auth
pytest

# Create database migration
make migration
```

### Documentation

```bash
# Serve documentation locally
make docs-serve

# Build documentation
make docs-build

# Lint documentation
make docs-lint
```

### Docker Swarm Deployment

```bash
# Set up local registry
make setup-registry

# Generate production secrets
./infrastructure/secrets/generate-secrets.sh

# Build and push images
make build-images

# Deploy to Swarm with secrets
docker-compose -f infrastructure/docker/docker-compose.yml \
               -f infrastructure/docker/docker-compose.secrets.yml up -d

# View Swarm services
make swarm-ps
```

### Frontend Development

```bash
cd frontend
npm install
npm run dev        # Start development server
npm run build      # Build for production
npm test          # Run tests
npm run lint      # Run linter
```

### Docker Operations

```bash
docker-compose up -d     # Start all services
docker-compose down      # Stop all services
docker-compose logs -f   # View logs
docker-compose ps        # Show running services
```

## Key Technologies

- **Backend**: Python 3.11+ (FastAPI), Go (for high-performance services)
- **Frontend**: React 18, TypeScript, Tailwind CSS, Vite
- **Databases**: PostgreSQL, TimescaleDB, Redis, OpenSearch
- **Infrastructure**: Docker Swarm (POC), Kubernetes (future), Terraform
- **AI/ML**: LangChain, OpenAI/Anthropic APIs, Pinecone
- **Monitoring**: Prometheus, Grafana, Jaeger
- **Package Management**: uv (Python), npm (JavaScript)
- **Documentation**: MkDocs with Material theme

## Service Ports

- Auth Service: 8001
- Portfolio Service: 8002
- Market Data Service: 8003
- AI/ML Service: 8004
- Analytics Service: 8005
- Frontend: 3000
- API Gateway: 8000
- PostgreSQL: 5432
- TimescaleDB: 5433
- Redis: 6379
- OpenSearch: 9200

## Project Memories

- Issues are now managed in github issues
- Discover and use all mcp servers available to you when required