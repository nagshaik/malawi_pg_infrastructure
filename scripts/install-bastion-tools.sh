#!/bin/bash
# Installation script for bastion tools
# Run this on the bastion host: sudo bash install-bastion-tools.sh

set -e

echo "================================================"
echo "Installing Bastion Tools - $(date)"
echo "================================================"

# Update packages
echo "Updating package lists..."
sudo apt-get update -y

# Install prerequisites
echo "Installing prerequisites..."
sudo apt-get install -y unzip curl ca-certificates jq wget

# Set PATH
export PATH=/usr/local/bin:$PATH

# AWS CLI v2
echo "Installing AWS CLI v2..."
cd /tmp
curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip
unzip -qo awscliv2.zip
sudo ./aws/install --bin-dir /usr/local/bin --install-dir /usr/local/aws-cli --update
rm -rf aws awscliv2.zip

# Verify AWS CLI
if command -v aws >/dev/null 2>&1; then
  echo "✓ AWS CLI installed: $(aws --version)"
else
  echo "✗ AWS CLI installation failed"
  exit 1
fi

# kubectl
echo "Installing kubectl..."
cd /tmp
KUBECTL_VER=$(curl -fsSL https://dl.k8s.io/release/stable.txt)
echo "Latest stable kubectl version: $KUBECTL_VER"
curl -fsSLO "https://dl.k8s.io/release/${KUBECTL_VER}/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# Verify kubectl
if command -v kubectl >/dev/null 2>&1; then
  echo "✓ kubectl installed: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
else
  echo "✗ kubectl installation failed"
  exit 1
fi

# ArgoCD CLI
echo "Installing ArgoCD CLI..."
cd /tmp
curl -fsSLO "https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64"
chmod +x argocd-linux-amd64
sudo mv argocd-linux-amd64 /usr/local/bin/argocd

# Verify ArgoCD CLI
if command -v argocd >/dev/null 2>&1; then
  echo "✓ ArgoCD CLI installed: $(argocd version --client --short 2>/dev/null || argocd version --client)"
else
  echo "✗ ArgoCD CLI installation failed"
  exit 1
fi

# Update PATH for ubuntu user
echo "Updating PATH for ubuntu user..."
if ! grep -q '/usr/local/bin' /home/ubuntu/.bashrc; then
  echo 'export PATH=/usr/local/bin:$PATH' >> /home/ubuntu/.bashrc
fi
if ! grep -q '/usr/local/bin' /home/ubuntu/.profile; then
  echo 'export PATH=/usr/local/bin:$PATH' >> /home/ubuntu/.profile
fi

echo ""
echo "================================================"
echo "Installation Complete!"
echo "================================================"
echo ""
echo "Installed tools:"
aws --version
kubectl version --client --short 2>/dev/null || kubectl version --client
argocd version --client --short 2>/dev/null || argocd version --client
echo ""
echo "Please log out and log back in for PATH changes to take effect."
echo "Or run: source ~/.bashrc"
echo ""
