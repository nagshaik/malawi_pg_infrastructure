#!/bin/bash
# Quick manual install for AWS CLI, kubectl, and ArgoCD CLI
# Run this on the bastion: bash fix-bastion-tools.sh

set -e

echo "=== Installing AWS CLI, kubectl, and ArgoCD CLI ==="
echo ""

# Update apt
echo "1. Updating apt..."
sudo apt-get update -y

# Install prerequisites
echo "2. Installing prerequisites..."
sudo apt-get install -y unzip curl jq wget

# AWS CLI v2
echo "3. Installing AWS CLI v2..."
cd /tmp
curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip
unzip -qo awscliv2.zip
sudo ./aws/install --bin-dir /usr/local/bin --install-dir /usr/local/aws-cli --update
rm -rf aws awscliv2.zip
echo "export PATH=/usr/local/bin:\$PATH" >> ~/.bashrc

# kubectl
echo "4. Installing kubectl..."
cd /tmp
KUBECTL_VERSION=$(curl -fsSL https://dl.k8s.io/release/stable.txt)
curl -fsSLO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm -f kubectl

# ArgoCD CLI
echo "5. Installing ArgoCD CLI..."
cd /tmp
curl -fsSLO "https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64"
sudo install -m 0755 argocd-linux-amd64 /usr/local/bin/argocd
rm -f argocd-linux-amd64

# Update PATH immediately
export PATH=/usr/local/bin:$PATH

echo ""
echo "=== Installation Complete ==="
echo ""
echo "Versions:"
/usr/local/bin/aws --version
/usr/local/bin/kubectl version --client --short 2>/dev/null || /usr/local/bin/kubectl version --client
/usr/local/bin/argocd version --client 2>&1 | head -1
echo ""
echo "NOTE: Run 'source ~/.bashrc' or logout/login to update PATH"
