# NexaNest v2.0 - AI-Powered Investment Portfolio Management Platform

NexaNest is a next-generation investment portfolio management platform that democratizes
institutional-grade financial analytics through AI, making sophisticated investment insights
accessible to individual investors and financial advisors.

## 🚀 Features

- **Multi-Portfolio Management**: Create and manage multiple investment portfolios
- **Real-time Market Data**: Live price updates and historical data analysis
- **AI-Powered Insights**: Natural language portfolio analysis and recommendations
- **Risk Assessment**: Advanced risk metrics and portfolio optimization
- **Collaborative Tools**: Features for financial advisors and their clients
- **Export Capabilities**: Generate PDF reports and Excel exports
- **Security First**: SOC 2 compliant architecture with end-to-end encryption

## 🏗️ Architecture

NexaNest is built using a microservices architecture for scalability and maintainability:

- **Frontend**: React 18 with TypeScript, Tailwind CSS
- **Backend Services**: Python (FastAPI) for AI/ML, Go for high-performance services
- **Databases**: PostgreSQL, TimescaleDB, Redis, OpenSearch
- **AI/ML**: Multi-provider support (OpenAI, Anthropic) via LangChain
- **Infrastructure**: Kubernetes, Docker, Terraform

See [Architecture Documentation](docs/ARCHITECTURE.md) for detailed information.

## 🚀 Getting Started

### Prerequisites

- Docker and Docker Compose
- Python 3.11+
- Node.js 18+
- Make (optional but recommended)

### Quick Start

1. **Clone the repository**

   ```bash
   git clone https://github.com/nexanest/nexanest.git
   cd nexanest
   ```

1. **Set up environment and secrets**

   ```bash
   # Automated setup with secure password generation
   ./scripts/setup-secrets.sh
   
   # Or manual setup
   cp .env.example .env
   cp .env.db.example .env.db
   # Edit .env files with your configuration
   ```

1. **Start development environment**

   ```bash
   make dev
   ```

1. **Run services**

   ```bash
   # Start auth service
   cd services/auth
   pip install -e .
   python -m app.main

   # Start frontend
   cd frontend
   npm install
   npm run dev
   ```

1. **Access the application**

   - Frontend: [http://localhost:3000](http://localhost:3000)
   - API Gateway: [http://localhost:8000](http://localhost:8000)
   - API Documentation: [http://localhost:8001/docs](http://localhost:8001/docs)

## 📁 Project Structure

```text
nexanest/
├── docs/                    # Documentation
│   ├── ARCHITECTURE.md      # System architecture
│   └── IMPLEMENTATION_PLAN.md
├── services/                # Microservices
│   ├── auth/                # Authentication service
│   ├── portfolio/           # Portfolio management
│   ├── market-data/         # Market data service
│   ├── ai-ml/               # AI/ML service
│   ├── analytics/           # Analytics engine
│   └── notification/        # Notification service
├── frontend/                # React application
├── infrastructure/          # IaC and K8s configs
├── scripts/                 # Utility scripts
└── shared/                  # Shared libraries
```

## 💻 Development

### Available Commands

```bash
make help     # Show all available commands
make setup    # Initial project setup
make dev      # Start development environment
make test     # Run all tests
make lint     # Run linters
make format   # Format code
```

### Running Tests

```bash
# Run all tests
make test

# Run specific service tests
cd services/auth && pytest

# Run frontend tests
cd frontend && npm test
```

### Code Standards

- Python: Ruff for linting and formatting
- TypeScript/JavaScript: ESLint and Prettier
- Git: Conventional commits
- Testing: Minimum 80% code coverage

## 🔒 Security & Secrets Management

NexaNest implements enterprise-grade security with comprehensive secrets management:

### Security Features
- All data encrypted in transit (TLS 1.3) and at rest (AES-256)
- OAuth2/OIDC authentication with MFA support
- Row-level security in PostgreSQL
- API rate limiting and DDoS protection
- Regular security audits and penetration testing

### Secrets Management
- **Docker Secrets**: Production-ready secrets management with Docker Swarm/Kubernetes
- **Environment Variables**: Development-friendly configuration with automatic generation
- **Service Isolation**: Individual .env files for each microservice
- **Security Best Practices**: No secrets in git, secure password generation, rotation support

```bash
# Quick setup with secure password generation
./scripts/setup-secrets.sh

# Production deployment with Docker secrets
docker-compose -f infrastructure/docker/docker-compose.yml \
               -f infrastructure/docker/docker-compose.secrets.yml up -d
```

See [Secrets Management Documentation](docs/infrastructure/secrets-management.md) for complete details.

## 📊 Performance Targets

- API response time < 100ms (p95)
- Dashboard load time < 2 seconds
- Real-time data updates < 500ms latency
- Support for 10,000+ concurrent users
- 99.9% uptime SLA

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

1. Fork the repository
1. Create your feature branch (`git checkout -b feature/amazing-feature`)
1. Commit your changes (`git commit -m 'Add amazing feature'`)
1. Push to the branch (`git push origin feature/amazing-feature`)
1. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built with modern open-source technologies
- Inspired by institutional-grade portfolio management systems
- Community-driven development

## 📞 Support

- Documentation: [docs.nexanest.com](https://docs.nexanest.com)
- Issues: [GitHub Issues](https://github.com/nexanest/nexanest/issues)
- Discussions: [GitHub Discussions](https://github.com/nexanest/nexanest/discussions)
- Email: [support@nexanest.com](mailto:support@nexanest.com)

______________________________________________________________________

**NexaNest v2.0** - Democratizing Financial Intelligence 🚀
