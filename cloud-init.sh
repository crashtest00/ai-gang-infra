#!/bin/bash
# AI Gang - Development HQ Setup
# Containerized per-project workspaces

set -e

# Allow Terraform remote-exec provisioner to connect as root during setup
mkdir -p /root/.ssh
chmod 700 /root/.ssh
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID80ZcpPckmQNrkQuUr5TSkU/MTykWWzJj1bZcyUVlEY ai-gang-hq" > /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys

# Clear password expiry (stops PAM from intercepting SSH sessions), then lock
chage -d $(date +%Y-%m-%d) -M 99999 root
passwd -l root

echo "Setting up AI Gang Development Headquarters..."

# Update package list only (skip full upgrade to avoid kernel reboot during init)
DEBIAN_FRONTEND=noninteractive apt-get update

# Install base tools
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  git \
  curl \
  wget \
  vim \
  nano \
  jq \
  build-essential \
  sudo

# Install Docker
echo "Installing Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
rm get-docker.sh

# Install Docker Compose V2
mkdir -p /usr/local/lib/docker/cli-plugins
curl -SL https://github.com/docker/compose/releases/download/v2.23.0/docker-compose-linux-x86_64 \
  -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

# Verify Docker installations
docker --version
docker compose version

# Install Node.js 22.x LTS (for potential host-level tasks)
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs

# Install Terraform
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list
DEBIAN_FRONTEND=noninteractive apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y terraform

# Create aigang user
useradd -m -s /bin/bash aigang
usermod -aG sudo aigang
usermod -aG docker aigang

# Passwordless sudo
echo "aigang ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/aigang
chmod 440 /etc/sudoers.d/aigang

# SSH setup
mkdir -p /home/aigang/.ssh
chmod 700 /home/aigang/.ssh
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID80ZcpPckmQNrkQuUr5TSkU/MTykWWzJj1bZcyUVlEY ai-gang-hq" > /home/aigang/.ssh/authorized_keys
chown -R aigang:aigang /home/aigang/.ssh
chmod 600 /home/aigang/.ssh/authorized_keys

# Git config
sudo -u aigang git config --global user.email "ai-gang@dev"
sudo -u aigang git config --global user.name "AI Gang"

# Create AI Gang structure
sudo -u aigang bash << 'USEREOF'
mkdir -p ~/ai-gang/{setup,projects}

# Create shared agent definition files
cat > ~/ai-gang/setup/cloud-engineering-agent.md << 'AGENT'
# Cloud Engineering Agent

## Your Role
You are the Cloud Engineering Agent for the AI Gang.

## Responsibilities
- CI/CD pipelines
- Infrastructure as Code
- Deployment automation
- Observability setup
- Secrets management

## Working Environment
You work inside a Docker container with:
- Access to this project's code at /workspace
- Access to shared best practices at /agent-docs
- NO access to other projects (container isolation)

## Key Principles
1. Build-once-promote
2. Policy-as-code
3. Behavioral examples over contracts
4. Reproducible infrastructure

See /agent-docs for complete documentation.
AGENT

cat > ~/ai-gang/setup/frontend-agent.md << 'AGENT'
# Frontend Agent

## Your Role
You are the Frontend Agent for the AI Gang.

## Responsibilities
- UI/UX development
- Component architecture
- Frontend testing
- Performance optimization
- Accessibility

## Working Environment
You work inside a Docker container with:
- Access to this project's code at /workspace
- Access to shared best practices at /agent-docs
- NO access to other projects (container isolation)

See /agent-docs for complete documentation.
AGENT

cat > ~/ai-gang/setup/backend-agent.md << 'AGENT'
# Backend Agent

## Your Role
You are the Backend Agent for the AI Gang.

## Responsibilities
- API development
- Database design
- Authentication/authorization
- Backend testing
- Performance optimization

## Working Environment
You work inside a Docker container with:
- Access to this project's code at /workspace
- Access to shared best practices at /agent-docs
- NO access to other projects (container isolation)

See /agent-docs for complete documentation.
AGENT

# Create README
cat > ~/ai-gang/README.md << 'README'
# AI Gang - Development Headquarters

## Architecture
This droplet hosts containerized development workspaces.
Each project runs in its own isolated Docker container.

## Structure
- `setup/` - Shared agent definitions (mounted read-only in all containers)
- `projects/` - Individual project workspaces (each with own container)

## Creating New Projects
See USER_GUIDE.md for step-by-step instructions.

## This Server Is For
✅ Containerized development
✅ Running tests in containers
✅ Building from containers
✅ Deploying from containers

## This Server Is NOT For
❌ Hosting production applications
❌ Serving user traffic
❌ Storing production data
README

USEREOF

# Enable Docker
systemctl enable docker
systemctl start docker

# Completion marker
touch /var/log/cloud-init-complete
echo "AI Gang Development HQ initialized at $(date)" > /var/log/cloud-init-complete

# Lock down root SSH — provisioning complete, use aigang user going forward
rm -f /root/.ssh/authorized_keys
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
systemctl reload ssh

echo "Setup complete! Projects will run in isolated containers."
