---
title: "Runbook Template"
description: "Template for operational runbooks for NexaNest services and systems"
authors:
  - "DevOps Team"
datetime: "2025-11-06 15:25:00"
status: "approved"
tags:
  - "template"
  - "runbook"
  - "operations"
  - "incident-response"
category: "operations"
audience: "operator"
complexity: "beginner"
technology_stack:
  - "Markdown"
business_value: "high"
template_version: "1.0"
---

# [Service/System Name] Runbook

## Overview

**Service**: [Service name]
**Owner**: [Team/Individual responsible]
**Last Updated**: [Date]
**Next Review**: [Date]

### Purpose
[Brief description of what this service does and its role in the system]

### Dependencies
- **Upstream**: [Services that this depends on]
- **Downstream**: [Services that depend on this]
- **Data Stores**: [Databases, caches, etc.]
- **External**: [Third-party services, APIs]

## Service Health

### Key Metrics
| Metric | Normal Range | Alert Threshold | Critical Threshold |
|--------|--------------|-----------------|-------------------|
| Response Time | < 100ms | > 200ms | > 500ms |
| Error Rate | < 1% | > 2% | > 5% |
| CPU Usage | < 70% | > 80% | > 90% |
| Memory Usage | < 75% | > 85% | > 95% |

### Health Check Endpoints
- **Primary**: `GET /health`
- **Detailed**: `GET /health/detailed`
- **Dependencies**: `GET /health/dependencies`

### Monitoring Dashboards
- [Grafana Dashboard URL]
- [Datadog Dashboard URL]
- [CloudWatch Dashboard URL]

## Common Issues and Solutions

### High Response Time

**Symptoms**:
- Response time > 200ms
- Increased queue length
- Customer complaints

**Diagnosis**:
```bash
# Check response time metrics
curl -s https://api.nexanest.com/metrics | grep response_time

# Check database connections
kubectl logs -f deployment/[service-name] | grep "database"

# Check resource usage
kubectl top pods -l app=[service-name]
```

**Resolution**:
1. Scale horizontally if CPU/Memory high
2. Check database query performance
3. Review recent deployments
4. Clear caches if applicable

### Database Connection Issues

**Symptoms**:
- Connection timeouts
- "Too many connections" errors
- Database-related 500 errors

**Diagnosis**:
```bash
# Check connection pool
kubectl exec -it deployment/[service-name] -- curl localhost:8080/metrics | grep db_connections

# Check database status
kubectl exec -it postgres-0 -- psql -U postgres -c "SELECT * FROM pg_stat_activity;"
```

**Resolution**:
1. Review connection pool configuration
2. Check for connection leaks
3. Restart service if necessary
4. Scale database if required

### Memory Leaks

**Symptoms**:
- Gradually increasing memory usage
- Out of memory errors
- Pod restarts

**Diagnosis**:
```bash
# Check memory trends
kubectl top pods -l app=[service-name] --containers

# Get memory profile
kubectl exec -it deployment/[service-name] -- curl localhost:8080/debug/pprof/heap > heap.prof
```

**Resolution**:
1. Analyze heap dump
2. Review recent code changes
3. Implement memory limits
4. Consider garbage collection tuning

## Operational Procedures

### Deployment

```bash
# Standard deployment
kubectl apply -f k8s/
kubectl rollout status deployment/[service-name]

# Rollback if needed
kubectl rollout undo deployment/[service-name]

# Check deployment status
kubectl get pods -l app=[service-name]
```

### Scaling

**Horizontal Scaling**:
```bash
# Scale up
kubectl scale deployment [service-name] --replicas=5

# Scale down
kubectl scale deployment [service-name] --replicas=2

# Auto-scaling
kubectl autoscale deployment [service-name] --cpu-percent=70 --min=2 --max=10
```

**Vertical Scaling**:
```bash
# Update resource limits
kubectl patch deployment [service-name] -p '{"spec":{"template":{"spec":{"containers":[{"name":"[container-name]","resources":{"limits":{"memory":"2Gi","cpu":"1000m"}}}]}}}}'
```

### Configuration Updates

```bash
# Update config map
kubectl create configmap [service-name]-config --from-file=config.yaml --dry-run=client -o yaml | kubectl apply -f -

# Restart to pick up new config
kubectl rollout restart deployment/[service-name]

# Verify config
kubectl exec -it deployment/[service-name] -- cat /etc/config/config.yaml
```

### Log Investigation

```bash
# Recent logs
kubectl logs -f deployment/[service-name] --tail=100

# Logs from specific time
kubectl logs deployment/[service-name] --since=1h

# Search for errors
kubectl logs deployment/[service-name] | grep -i error

# Export logs for analysis
kubectl logs deployment/[service-name] > service-logs.txt
```

## Emergency Procedures

### Service Down

1. **Immediate Response** (< 5 minutes):
   ```bash
   # Check pod status
   kubectl get pods -l app=[service-name]
   
   # Check recent events
   kubectl get events --sort-by=.metadata.creationTimestamp
   
   # Quick restart
   kubectl rollout restart deployment/[service-name]
   ```

2. **Investigation** (< 15 minutes):
   - Check monitoring dashboards
   - Review recent deployments
   - Analyze error logs
   - Check dependencies

3. **Resolution**:
   - Rollback if deployment-related
   - Scale up if capacity issue
   - Fix configuration if config-related
   - Coordinate with dependent teams

### Data Corruption

1. **Stop Traffic**:
   ```bash
   kubectl scale deployment [service-name] --replicas=0
   ```

2. **Assess Damage**:
   - Check data integrity
   - Identify affected time range
   - Estimate impact scope

3. **Recovery**:
   - Restore from backup
   - Run data validation
   - Gradually restore traffic

### Security Incident

1. **Immediate Actions**:
   - Isolate affected components
   - Preserve evidence
   - Notify security team

2. **Investigation**:
   - Analyze access logs
   - Check for unauthorized changes
   - Assess data exposure

## Contacts

### On-Call Rotation
- **Primary**: [Slack channel or phone]
- **Secondary**: [Backup contact]
- **Escalation**: [Manager/Senior engineer]

### Team Contacts
- **Product Owner**: @product-owner
- **Tech Lead**: @tech-lead
- **DevOps**: @devops-team
- **Security**: @security-team

## Documentation Links

- [Architecture Documentation]
- [API Documentation]
- [Deployment Guide]
- [Configuration Reference]
- [Monitoring Setup]

## Changelog

| Date | Change | Author |
|------|--------|--------|
| 2024-01-01 | Initial version | @author |
| 2024-01-15 | Added scaling procedures | @author2 |