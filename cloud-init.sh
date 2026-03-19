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

# Write GitHub deploy key
cat > /home/aigang/.ssh/github << 'DEPLOYKEY'
${github_deploy_key}
DEPLOYKEY
chmod 600 /home/aigang/.ssh/github

# Configure SSH to use deploy key for GitHub
cat > /home/aigang/.ssh/config << 'SSHCONFIG'
Host github.com
  HostName github.com
  User git
  IdentityFile ~/.ssh/github
SSHCONFIG
chmod 600 /home/aigang/.ssh/config

# Add GitHub to known hosts (avoids interactive prompt during clone)
ssh-keyscan github.com >> /home/aigang/.ssh/known_hosts
chmod 644 /home/aigang/.ssh/known_hosts
chown -R aigang:aigang /home/aigang/.ssh

# Clone AI Gang repo
sudo -u aigang git clone git@github.com:crashtest00/aigang.git /home/aigang/ai-gang

# Create projects dir (not tracked in repo)
mkdir -p /home/aigang/ai-gang/projects
chown aigang:aigang /home/aigang/ai-gang/projects

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
