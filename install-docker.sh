#!/bin/bash
# =============================================================================
# install-docker.sh
# Installs Docker Engine on Ubuntu 20.04 / 22.04
# Usage: bash install-docker.sh
# =============================================================================

set -e

echo "──────────────────────────────────────────"
echo " Docker Installation Script"
echo "──────────────────────────────────────────"

# Step 1: Update package list
echo "[1/6] Updating packages..."
sudo apt-get update -y

# Step 2: Install dependencies
echo "[2/6] Installing dependencies..."
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Step 3: Add Docker's GPG key
echo "[3/6] Adding Docker GPG key..."
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Step 4: Add Docker repository
echo "[4/6] Adding Docker repository..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Step 5: Install Docker Engine
echo "[5/6] Installing Docker Engine..."
sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io

# Step 6: Enable and start Docker
echo "[6/6] Enabling Docker service..."
sudo systemctl enable docker
sudo systemctl start docker

# Optional: allow current user to run docker without sudo
sudo usermod -aG docker $USER

echo ""
echo "✅ Docker installed successfully!"
echo ""
docker --version
echo ""
echo "NOTE: Log out and back in (or run 'newgrp docker') to use Docker without sudo."
