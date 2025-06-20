# SSH Access Setup for Docker Swarm

This guide explains how to configure SSH access to Docker Swarm nodes for automated deployment and management.

## 🔑 Environment Variables Created

The following environment variables have been added to support SSH access to Docker Swarm nodes:

### Main Configuration (.env)
```bash
# Docker Swarm cluster configuration
SWARM_MANAGER_HOST=your_swarm_manager_ip_or_hostname
SWARM_MANAGER_USER=ubuntu
SWARM_MANAGER_PORT=22
SWARM_MANAGER_SSH_KEY_PATH=~/.ssh/swarm-manager-key.pem

# Worker nodes (comma-separated)
SWARM_WORKER_HOSTS=worker1_ip,worker2_ip,worker3_ip
SWARM_WORKER_USER=ubuntu
SWARM_WORKER_PORT=22
SWARM_WORKER_SSH_KEY_PATH=~/.ssh/swarm-worker-key.pem

# Network and cluster settings
SWARM_ADVERTISE_ADDR=your_manager_private_ip
SWARM_NETWORK_NAME=nexanest-network
SWARM_PERSISTENT_VOLUME_PATH=/opt/nexanest/data
```

### Detailed Configuration (.env.swarm)
Contains comprehensive settings for:
- Individual worker node configurations
- Network and storage settings
- Load balancer configuration
- Monitoring and security settings
- Resource limits and deployment strategies

## 🚀 Quick Setup

### 1. Generate Environment Files
```bash
# Generate all environment templates with secure passwords
./scripts/setup-secrets.sh
```

### 2. Configure SSH Access
Edit `.env.swarm` with your actual infrastructure details:

```bash
# Manager node
SWARM_MANAGER_HOST=10.0.1.10
SWARM_MANAGER_USER=ubuntu
SWARM_MANAGER_SSH_KEY_PATH=~/.ssh/id_rsa_swarm

# Worker nodes
SWARM_WORKER_1_HOST=10.0.1.11
SWARM_WORKER_2_HOST=10.0.1.12
SWARM_WORKER_3_HOST=10.0.1.13
```

### 3. Set Up SSH Keys
```bash
# Generate SSH key pair (if needed)
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa_swarm -C "nexanest-swarm"

# Copy public key to all nodes
ssh-copy-id -i ~/.ssh/id_rsa_swarm.pub ubuntu@10.0.1.10  # manager
ssh-copy-id -i ~/.ssh/id_rsa_swarm.pub ubuntu@10.0.1.11  # worker1
ssh-copy-id -i ~/.ssh/id_rsa_swarm.pub ubuntu@10.0.1.12  # worker2
ssh-copy-id -i ~/.ssh/id_rsa_swarm.pub ubuntu@10.0.1.13  # worker3
```

### 4. Test SSH Connectivity
```bash
# Test SSH access to all nodes
./scripts/swarm-manage.sh test-connection
```

### 5. Initialize Docker Swarm
```bash
# Complete swarm setup (install Docker + initialize cluster)
./scripts/swarm-manage.sh setup
```

## 📋 Required Information

To configure SSH access, you'll need:

### Infrastructure Details
- **IP addresses** or hostnames of all Swarm nodes
- **SSH usernames** (typically `ubuntu`, `ec2-user`, or `root`)
- **SSH port** (usually 22)
- **Network configuration** (subnets, security groups)

### Authentication Method
Choose one of:

#### Option 1: SSH Key Pairs (Recommended)
- Private key files (`.pem` or standard SSH keys)
- Public keys deployed to all nodes
- Key file permissions set to 600

#### Option 2: Password Authentication (Less Secure)
- SSH passwords for each node
- Sudo passwords (if different)

### Cloud Provider Specifics

#### AWS EC2
```bash
SWARM_MANAGER_HOST=ec2-xxx-xxx-xxx-xxx.compute-1.amazonaws.com
SWARM_MANAGER_USER=ubuntu  # or ec2-user for Amazon Linux
SWARM_MANAGER_SSH_KEY_PATH=~/.ssh/my-keypair.pem
```

#### Google Cloud Platform
```bash
SWARM_MANAGER_HOST=xxx.xxx.xxx.xxx
SWARM_MANAGER_USER=your-username
SWARM_MANAGER_SSH_KEY_PATH=~/.ssh/google_compute_engine
```

#### DigitalOcean
```bash
SWARM_MANAGER_HOST=xxx.xxx.xxx.xxx
SWARM_MANAGER_USER=root
SWARM_MANAGER_SSH_KEY_PATH=~/.ssh/digitalocean_rsa
```

#### Azure
```bash
SWARM_MANAGER_HOST=xxx.xxx.xxx.xxx
SWARM_MANAGER_USER=azureuser
SWARM_MANAGER_SSH_KEY_PATH=~/.ssh/azure_rsa
```

## 🔧 Management Commands

### Swarm Management Script
```bash
# Available commands
./scripts/swarm-manage.sh help

# Test SSH connectivity
./scripts/swarm-manage.sh test-connection

# Install Docker on all nodes
./scripts/swarm-manage.sh install-docker

# Initialize swarm cluster
./scripts/swarm-manage.sh init

# Join workers to cluster
./scripts/swarm-manage.sh join-workers

# Check cluster status
./scripts/swarm-manage.sh status

# Create overlay network
./scripts/swarm-manage.sh create-network

# Deploy application stack
./scripts/swarm-manage.sh deploy nexanest

# Complete setup (all steps)
./scripts/swarm-manage.sh setup
```

### Manual SSH Commands
```bash
# Connect to manager node
ssh -i ~/.ssh/id_rsa_swarm ubuntu@$SWARM_MANAGER_HOST

# Check swarm status
ssh -i ~/.ssh/id_rsa_swarm ubuntu@$SWARM_MANAGER_HOST "docker node ls"

# View running services
ssh -i ~/.ssh/id_rsa_swarm ubuntu@$SWARM_MANAGER_HOST "docker service ls"
```

## 🛡️ Security Best Practices

### SSH Key Management
```bash
# Set proper permissions on SSH keys
chmod 600 ~/.ssh/id_rsa_swarm
chmod 644 ~/.ssh/id_rsa_swarm.pub

# Use SSH agent for key management
ssh-add ~/.ssh/id_rsa_swarm
```

### Network Security
- Use private networks for node communication
- Configure security groups/firewalls to limit access
- Use jump servers/bastions for production environments
- Enable SSH key rotation and monitoring

### Access Control
- Use dedicated SSH keys for Swarm management
- Implement least-privilege access principles
- Monitor SSH access logs
- Use SSH certificates for enterprise environments

## 🔍 Troubleshooting

### Common SSH Issues

#### Permission Denied
```bash
# Check SSH key permissions
ls -la ~/.ssh/id_rsa_swarm
chmod 600 ~/.ssh/id_rsa_swarm

# Verify public key is on remote host
ssh-copy-id -i ~/.ssh/id_rsa_swarm.pub ubuntu@$HOST
```

#### Connection Timeout
```bash
# Check if host is reachable
ping $SWARM_MANAGER_HOST

# Test specific port
telnet $SWARM_MANAGER_HOST 22

# Check security group/firewall rules
```

#### Docker Not Found
```bash
# Install Docker on node
./scripts/swarm-manage.sh install-docker

# Or manually:
ssh -i ~/.ssh/id_rsa_swarm ubuntu@$HOST "curl -fsSL https://get.docker.com | sh"
```

### Debug Mode
```bash
# Enable verbose SSH output
ssh -v -i ~/.ssh/id_rsa_swarm ubuntu@$HOST

# Check SSH configuration
ssh -F /dev/null -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa_swarm ubuntu@$HOST
```

## 📚 Related Documentation

- [Secrets Management](secrets-management.md) - Environment variables and Docker secrets
- [Docker Swarm Setup](swarm-setup-prompt.md) - Complete cluster setup guide
- [Remote Docker Setup](remote-docker-setup.md) - Remote Docker configuration

## 🆘 Getting Help

If you encounter issues:

1. **Check SSH connectivity** first with `test-connection` command
2. **Verify environment variables** are correctly set in `.env.swarm`
3. **Review SSH key permissions** and paths
4. **Check network connectivity** and security groups
5. **Consult logs** for detailed error messages

For additional support, refer to the [troubleshooting guide](../troubleshooting.md) or create an issue in the project repository.