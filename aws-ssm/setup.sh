#!/bin/bash

# Supports: Ubuntu/Debian systems only

set -e

# Check if required parameters are provided
if [ $# -ne 3 ]; then
    echo "Usage: $0 <ssm_agent_code> <ssm_agent_id> <ssm_agent_region>"
    echo "Please provide the SSM Agent activation code, ID, and region."
    echo "Example: $0 asasasa jsjsjs-xxxx-yyyy-asasa-asss eu-central-1"
    exit 1
fi

SSM_AGENT_CODE="$1"
SSM_AGENT_ID="$2"  # Fixed: removed extra =
SSM_AGENT_REGION="$3"

echo "Starting SSM Agent setup..."
echo "SSM Agent Code: $SSM_AGENT_CODE"
echo "SSM Agent ID: $SSM_AGENT_ID"
echo "SSM Agent Region: $SSM_AGENT_REGION"

# Update system packages
echo "Updating system packages..."
sudo apt-get update -y

# Install SSM Agent using snap (official method)
echo "Installing SSM Agent..."
if ! sudo snap list amazon-ssm-agent >/dev/null 2>&1; then
    echo "Installing SSM Agent via snap..."
    sudo snap install amazon-ssm-agent --classic
    echo "SSM Agent installed successfully"
else
    echo "SSM Agent is already installed"
fi

# Check SSM Agent status and start if needed
echo "Checking SSM Agent status..."
if sudo snap services amazon-ssm-agent | grep -q "inactive\|disabled\|stopped"; then
    echo "Starting SSM Agent service..."
    sudo snap start amazon-ssm-agent
else
    echo "SSM Agent is already running"
fi

# Verify SSM Agent is running
echo "Verifying SSM Agent service status..."
sudo snap services amazon-ssm-agent

# Install Docker if not present
echo "Installing Docker..."
if ! command -v docker >/dev/null 2>&1; then
    # Install prerequisites
    sudo apt-get install -y ca-certificates curl gnupg lsb-release
    
    # Add Docker's official GPG key
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # Set up the repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker Engine
    sudo apt-get update -y
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Enable and start Docker
    sudo systemctl enable docker
    sudo systemctl start docker
    
    # Add current user to docker group
    sudo usermod -a -G docker $USER
    
    echo "Docker installed successfully"
else
    echo "Docker is already installed"
fi

# Install Docker Compose (standalone version)
echo "Installing Docker Compose..."
if ! command -v docker-compose >/dev/null 2>&1; then
    # Get the latest stable release version
    DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
    
    # Download and install Docker Compose
    sudo curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    
    # Make it executable
    sudo chmod +x /usr/local/bin/docker-compose
    
    # Create symlink for easier access
    sudo ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
    
    echo "Docker Compose ${DOCKER_COMPOSE_VERSION} installed successfully"
else
    echo "Docker Compose is already installed"
fi

# Verify Docker installation
echo "Verifying Docker installation..."
if command -v docker >/dev/null 2>&1; then
    echo "✅ Docker version: $(docker --version)"
    
    # Test Docker daemon
    if sudo docker run --rm hello-world >/dev/null 2>&1; then
        echo "✅ Docker is working correctly"
    else
        echo "⚠️ Docker installed but may have issues"
    fi
else
    echo "❌ Docker installation failed"
fi

# Verify Docker Compose installation
echo "Verifying Docker Compose installation..."
if command -v docker-compose >/dev/null 2>&1; then
    echo "✅ Docker Compose version: $(docker-compose --version)"
else
    echo "❌ Docker Compose installation failed"
fi

# Configure SSM Agent with the provided activation code and region
echo "Configuring SSM Agent..."
if sudo /snap/amazon-ssm-agent/current/amazon-ssm-agent -register -code "$SSM_AGENT_CODE" -id "$SSM_AGENT_ID" -region "$SSM_AGENT_REGION" -y; then
    echo "✅ SSM Agent registered successfully"
else
    echo "⚠️ SSM Agent registration may have failed, checking status..."
fi

# Restart SSM Agent service to ensure registration takes effect
echo "Restarting SSM Agent service..."
sudo snap restart amazon-ssm-agent

# Wait for service to fully restart
sleep 3

# Verify SSM Agent final status
echo "Final SSM Agent status check..."
echo "Service status:"
sudo snap services amazon-ssm-agent

echo "Registration status:"
if sudo /snap/amazon-ssm-agent/current/amazon-ssm-agent -status 2>/dev/null; then
    echo "✅ SSM Agent is properly registered"
else
    echo "⚠️ SSM Agent registration status unclear"
fi

echo ""
echo "🎉 Setup completed successfully!"
echo "📋 Installed components:"
echo "   - SSM Agent: ✅ (via snap)"
echo "   - Docker: ✅"
echo "   - Docker Compose: ✅"
echo ""
echo "💡 Note: You may need to log out and log back in for Docker group permissions to take effect"
echo "💡 To test Docker without sudo, run: newgrp docker"
echo ""
echo "🔧 SSM Agent commands for troubleshooting:"
echo "   - Check status: sudo snap services amazon-ssm-agent"
echo "   - Start service: sudo snap start amazon-ssm-agent"
echo "   - Check registration: sudo /snap/amazon-ssm-agent/current/amazon-ssm-agent -status"