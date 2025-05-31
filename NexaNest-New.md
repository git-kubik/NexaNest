# NexaNest v2.0 - Project Inception Prompt

## Project Mission & Vision

**Mission**: Build a next-generation investment portfolio management platform that democratizes
institutional-grade financial analytics through AI, making sophisticated investment insights accessible
to individual investors and financial advisors.

**Vision**: Create the most intuitive, intelligent, and comprehensive investment platform that empowers
users to make data-driven financial decisions with confidence.

## Core Requirements

Design and implement a modern investment portfolio platform with the following capabilities:

### 1. Portfolio Management

- Multi-portfolio support with real-time tracking
- Asset allocation optimization
- Performance analytics and reporting
- Risk assessment and management
- Rebalancing recommendations

### 2. AI-Powered Intelligence

- Natural language portfolio analysis
- Market trend predictions
- Personalized investment recommendations
- Similarity-based asset discovery
- Automated insight generation
- Support for multiple AI providers (OpenAI, Anthropic, etc.)

### 3. Market Data & Analytics

- Real-time and historical price data
- Technical indicators and charting
- Market sentiment analysis
- News aggregation and impact assessment
- Sector and industry analysis

### 4. User Experience

- Intuitive dashboard with customizable widgets
- Mobile-responsive design
- Real-time notifications and alerts
- Collaborative features for advisors/clients
- Export capabilities (PDF reports, Excel)

## Technical Requirements

### Performance Targets

- API response time < 100ms (p95)
- Dashboard initial load < 2 seconds
- Real-time data updates < 500ms latency
- Support 10,000+ concurrent users
- 99.9% uptime SLA

### Security & Compliance

- SOC 2 Type II compliant architecture
- End-to-end encryption for sensitive data
- Multi-factor authentication
- Role-based access control (RBAC)
- Audit logging and compliance reporting
- GDPR/CCPA compliance ready

### Scalability & Reliability

- Horizontally scalable architecture
- Auto-scaling based on load
- Multi-region deployment capability
- Disaster recovery with RTO < 1 hour
- Data backup and retention policies

## Architectural Considerations

Design the system with these principles in mind:

### 1. Microservices Architecture

- Domain-driven design
- Service mesh for communication
- API gateway pattern
- Event-driven communication where appropriate

### 2. Data Architecture

- CQRS pattern for read/write optimization
- Event sourcing for audit trail
- Caching strategy (multi-tier)
- Real-time data streaming
- Time-series data optimization

### 3. AI/ML Infrastructure

- Model versioning and A/B testing
- Embeddings storage and similarity search
- Prompt management and optimization
- Cost optimization for LLM usage
- Fallback strategies for AI services

### 4. Frontend Architecture

- Progressive Web App (PWA) capabilities
- Micro-frontend consideration
- State management strategy
- Real-time updates (WebSocket/SSE)
- Offline capabilities

### 5. DevOps & Infrastructure

- Infrastructure as Code (IaC)
- CI/CD pipelines with automated testing
- Container orchestration
- Observability (metrics, logs, traces)
- Chaos engineering practices

## Constraints & Guidelines

- **Technology Agnostic**: Choose the best tools for each component
- **Cloud Native**: Design for cloud deployment from day one
- **API First**: All features accessible via well-documented APIs
- **Test Driven**: Minimum 80% code coverage
- **Documentation**: Architecture Decision Records (ADRs) for key decisions
- **Open Standards**: Prefer open standards and protocols
- **Cost Conscious**: Consider operational costs in design decisions

## Deliverables Expected

### 1. Architecture Design Document

- System architecture diagram
- Data flow diagrams
- Technology stack justification
- Security architecture
- Deployment architecture

### 2. Implementation Plan

- Phased delivery roadmap
- MVP feature set
- Risk mitigation strategies
- Team structure recommendations

### 3. Proof of Concept

- Core portfolio management
- Basic AI integration
- Real-time data pipeline
- Authentication/authorization
- Basic frontend

## Success Metrics

- User can create and manage portfolios within 3 clicks
- AI insights generated in < 2 seconds
- 95% accuracy in asset similarity matching
- Zero security breaches
- < 0.1% error rate in production
- User satisfaction score > 4.5/5

## Future Considerations

Design with these future features in mind:

- Cryptocurrency and DeFi integration
- Social trading features
- Automated trading strategies
- Mobile native applications
- White-label capabilities
- International market support
- Multiple language support

______________________________________________________________________

**Your task**: Design and begin implementing NexaNest v2.0 using modern architectural patterns and
technology choices that best serve the mission while ensuring scalability, security, and exceptional
user experience. Justify all major architectural decisions and provide a clear implementation roadmap.
