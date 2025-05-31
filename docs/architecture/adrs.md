---
title: Architecture Decision Records
description: Key architectural decisions for NexaNest
datetime: 2025-05-31 18:40:00
authors:
  - NexaNest Architecture Team
---

# Architecture Decision Records (ADRs)

This page consolidates all Architecture Decision Records for the NexaNest project.

## ADR-001: Microservices over Monolith

**Status**: Accepted\
**Date**: 2025-05-31\
**Decision**: Use microservices architecture\
**Rationale**: Better scalability, technology flexibility, team autonomy

## ADR-002: Python for AI Services, Go for Performance-Critical Services

**Status**: Accepted\
**Date**: 2025-05-31\
**Decision**: Use Python for AI/ML services, Go for high-performance services\
**Rationale**: Python has better AI/ML ecosystem, Go provides better performance

## ADR-003: Docker Swarm for Container Orchestration (POC Phase)

**Status**: Accepted\
**Date**: 2025-05-31\
**Decision**: Use Docker Swarm for POC deployment instead of Kubernetes\
**Rationale**: Existing operational Docker Swarm cluster, simpler for POC phase

## ADR-004: Event-Driven Architecture for Service Communication

**Status**: Accepted\
**Date**: 2025-05-31\
**Decision**: Use Kafka for event streaming\
**Rationale**: Decoupling, scalability, audit trail

## ADR-005: UV for Python Package Management

**Status**: Accepted\
**Date**: 2025-05-31\
**Decision**: Use uv for all Python dependency management\
**Rationale**: Faster, more reliable than pip, better dependency resolution

## ADR-006: Defer AWS-Specific Services

**Status**: Accepted\
**Date**: 2025-05-31\
**Decision**: Move AWS-specific implementations to future development\
**Rationale**: Focus on cloud-agnostic POC first

## ADR-007: Project as Proof of Concept (POC)

**Status**: Accepted\
**Date**: 2025-05-31\
**Decision**: Consider initial implementation as POC\
**Rationale**: Validate architecture and features before production build

## ADR-008: PostgreSQL Outside Swarm

**Status**: Accepted\
**Date**: 2025-05-31\
**Decision**: Deploy PostgreSQL container on Swarm node but outside Swarm orchestration\
**Rationale**: Database persistence and management considerations

## ADR-009: Local Docker Registry

**Status**: Accepted\
**Date**: 2025-05-31\
**Decision**: Use local Docker registry for image storage\
**Rationale**: Better control, no external dependencies for POC

## ADR-010: MkDocs for Documentation

**Status**: Accepted\
**Date**: 2025-05-31\
**Decision**: Use MkDocs with Material theme and Mermaid diagrams\
**Rationale**: Professional appearance, easy maintenance, good diagram support

## ADR-011: Documentation Standards

**Status**: Accepted\
**Date**: 2025-05-31\
**Decision**: All documentation must include frontmatter and be linted\
**Rationale**: Consistency, quality, and metadata management

## ADR-012: Australia/Adelaide Timezone for All Timestamps

**Status**: Accepted\
**Date**: 2025-05-31\
**Decision**: Use Australia/Adelaide timezone for all timestamps throughout the system\
**Rationale**: Consistent timezone handling, aligns with primary user base location

### Context

The system needs a consistent approach to handling timestamps across all services, databases, and user
interfaces. Different timezone approaches can lead to confusion and errors in time-sensitive operations
like trading hours, reporting, and audit trails.

### Decision

All timestamps in the NexaNest system will use Australia/Adelaide timezone (ACST/ACDT):
- Database storage: Store timestamps with timezone information
- API responses: Return timestamps in Australia/Adelaide timezone
- Log files: Use Australia/Adelaide timezone for all logging
- Scheduled jobs: Schedule based on Australia/Adelaide timezone
- User interface: Display times in Australia/Adelaide timezone by default

### Consequences

**Positive:**
- Consistency across all system components
- Simplified debugging and troubleshooting
- Clear audit trails for compliance
- Reduced timezone conversion errors
- Better alignment with Australian market hours

**Negative:**
- International users may need to mentally convert times
- Future expansion to other regions may require refactoring
- Daylight saving transitions need careful handling

### Implementation Notes

- Use `TZ=Australia/Adelaide` environment variable in all services
- Configure databases to use `Australia/Adelaide` as default timezone
- Use timezone-aware datetime objects in Python (`pytz` or `zoneinfo`)
- Document timezone assumptions in API specifications
- Include timezone information in all timestamp fields

## Summary Table

| ADR | Decision                   | Status   | Impact |
| --- | -------------------------- | -------- | ------ |
| 001 | Microservices architecture | Accepted | High   |
| 002 | Python/Go language split   | Accepted | High   |
| 003 | Docker Swarm for POC       | Accepted | Medium |
| 004 | Event-driven with Kafka    | Accepted | High   |
| 005 | UV package manager         | Accepted | Medium |
| 006 | Defer AWS services         | Accepted | Low    |
| 007 | POC approach               | Accepted | High   |
| 008 | PostgreSQL outside Swarm   | Accepted | Medium |
| 009 | Local Docker registry      | Accepted | Medium |
| 010 | MkDocs documentation       | Accepted | Low    |
| 011 | Documentation standards    | Accepted | Low    |
| 012 | Australia/Adelaide timezone | Accepted | Medium |

## Implementation Notes

- All Python projects must use `uv` for dependency management
- Documentation must be written in Markdown with frontmatter
- All documentation changes must pass linting before merge
- Docker images must be pushed to local registry at `localhost:5000`
- PostgreSQL should be deployed as a standalone container with persistent volumes
- AWS-specific features (S3, RDS, etc.) are deferred to post-POC phase
