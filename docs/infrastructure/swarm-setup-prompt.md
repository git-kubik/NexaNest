---
title: "Docker Swarm Remote Access Setup Prompt"
description: "Prompt template for configuring Docker Swarm cluster with remote TLS access for NexaNest deployment"
authors:
  - "DevOps Team"
datetime: "2025-11-06 15:15:00"
status: "approved"
tags:
  - "infrastructure"
  - "docker-swarm"
  - "remote-access"
  - "tls"
  - "deployment"
  - "template"
category: "operations"
audience: "operator"
complexity: "advanced"
technology_stack:
  - "Docker Swarm"
  - "TLS"
  - "Linux"
platforms:
  - "Linux"
minimum_version_requirements:
  docker: "20.10+"
business_value: "medium"
security_classification: "internal"
---

# Docker Swarm Remote Access Setup Prompt

Use this prompt in your Docker Swarm infrastructure project to configure remote access for the NexaNest deployment.

---

## 🐳 **Docker Swarm Remote Access Configuration Prompt**

I need to configure a Docker Swarm cluster with remote TLS access for the NexaNest project. The setup should include one manager node and three worker nodes, all accessible remotely for deployment and management.

### **Requirements:**

**Infrastructure:**
- 1 Swarm Manager node (will also run Docker registry on port 5000)
- 3 Swarm Worker nodes
- All nodes should accept remote Docker connections via TLS on port 2376
- Manager node should expose registry on port 5000
- Secure TLS certificate-based authentication

**Network Configuration:**
- Manager: Should be accessible from external clients for deployment
- Workers: Should communicate with manager and accept remote connections
- Registry: Accessible from external build systems and swarm nodes
- Firewall rules for ports: 22 (SSH), 2376 (Docker), 2377 (Swarm), 7946 (Swarm), 4789 (Overlay), 5000 (Registry)

**Security Requirements:**
- TLS mutual authentication for all Docker daemon connections
- Certificate Authority (CA) for signing all certificates
- Separate certificates for each node (manager + 3 workers)
- Client certificates for remote access from development machines
- Secure certificate distribution and management

**Services to Deploy:**
- Docker Registry (on manager node)
- Swarm mode enabled across all nodes
- Health checks and monitoring capabilities
- Automated certificate generation and deployment

### **Specific Tasks:**

1. **Certificate Infrastructure:**
   - Generate CA certificate and private key
   - Create server certificates for manager and each worker node
   - Generate client certificates for remote access
   - Set up secure certificate distribution mechanism

2. **Manager Node Configuration:**
   - Configure Docker daemon for remote TLS access on port 2376
   - Initialize Docker Swarm mode
   - Deploy Docker Registry container on port 5000
   - Configure registry with proper authentication and storage
   - Set up firewall rules for all required ports

3. **Worker Node Configuration:**
   - Configure Docker daemon for remote TLS access on port 2376
   - Join workers to the swarm cluster
   - Configure firewall rules for swarm communication
   - Set up health monitoring

4. **Network Security:**
   - Configure iptables/ufw rules for all nodes
   - Set up overlay networks for container communication
   - Configure registry to allow insecure access from swarm nodes
   - Implement proper network segmentation

5. **Management Scripts:**
   - Script to generate and distribute certificates
   - Health check scripts for all nodes
   - Swarm maintenance and backup scripts
   - Registry management and cleanup scripts

6. **Documentation:**
   - Node configuration details and IP addresses
   - Certificate locations and usage instructions
   - Firewall configuration reference
   - Troubleshooting guide for common issues

### **Environment Details:**

**Node Specifications:**
- OS: Ubuntu 20.04 LTS or 22.04 LTS
- Docker Engine: 20.10+ or 24.0+
- RAM: Minimum 2GB per node, 4GB for manager
- Storage: SSD preferred, at least 20GB per node
- Network: Gigabit connectivity between nodes

**Expected Output Structure:**
```
swarm-infrastructure/
├── scripts/
│   ├── generate-certificates.sh
│   ├── setup-manager.sh
│   ├── setup-worker.sh
│   ├── join-swarm.sh
│   └── health-check.sh
├── config/
│   ├── docker-daemon.json
│   ├── firewall-rules.sh
│   └── registry-config.yml
├── certs/
│   ├── ca/
│   ├── manager/
│   ├── worker-01/
│   ├── worker-02/
│   ├── worker-03/
│   └── client/
└── docs/
    ├── setup-guide.md
    ├── node-inventory.md
    └── troubleshooting.md
```

**Integration Requirements:**
The remote access should be compatible with these client commands from the NexaNest project:
```bash
# Remote Docker access
export DOCKER_HOST="tcp://manager-ip:2376"
export DOCKER_TLS_VERIFY=1
export DOCKER_CERT_PATH="/path/to/client/certs"

# Registry access
docker push manager-ip:5000/nexanest/service:tag

# Swarm deployment
docker stack deploy -c docker-compose.swarm.yml nexanest
```

**Automation Preferences:**
- Use shell scripts for maximum compatibility
- Include comprehensive error handling and logging
- Provide both manual and automated setup options
- Include rollback procedures for failed deployments

### **Security Considerations:**

1. **Certificate Management:**
   - CA private key should be stored securely (offline after generation)
   - Individual node certificates should not be interchangeable
   - Client certificates should be distributed securely
   - Include certificate rotation procedures

2. **Network Security:**
   - Disable Docker's default insecure port 2375
   - Use UFW or iptables for comprehensive firewall rules
   - Consider VPN access for additional security layer
   - Implement fail2ban for SSH protection

3. **Registry Security:**
   - Configure registry with authentication if needed
   - Set up proper volume mounts for persistent storage
   - Include registry cleanup and garbage collection
   - Monitor registry disk usage

### **Testing Requirements:**

Include scripts to test:
- Remote Docker connectivity to all nodes
- Swarm cluster health and node status
- Registry push/pull operations
- Overlay network connectivity
- Certificate validation and expiration monitoring

Please create a complete, production-ready setup that follows Docker and security best practices. Include detailed documentation for maintenance and troubleshooting.

---

**Note:** This prompt is designed to be used in a separate infrastructure project focused specifically on Docker Swarm cluster setup and management.