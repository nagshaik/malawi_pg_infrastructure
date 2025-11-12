#!/bin/bash
# Install AWS Load Balancer Controller for EKS

set -e

echo "======================================================"
echo "Installing AWS Load Balancer Controller"
echo "======================================================"
echo ""

# Variables
CLUSTER_NAME="malawi-pg-azampay-eks-cluster"
AWS_REGION="eu-central-1"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
VPC_ID=$(aws eks describe-cluster --name $CLUSTER_NAME --region $AWS_REGION --query "cluster.resourcesVpcConfig.vpcId" --output text)

echo "Cluster: $CLUSTER_NAME"
echo "Region: $AWS_REGION"
echo "Account: $AWS_ACCOUNT_ID"
echo "VPC: $VPC_ID"
echo ""

# Step 1: Create IAM Policy
echo "Step 1: Creating IAM Policy for AWS Load Balancer Controller..."
echo ""

POLICY_NAME="AWSLoadBalancerControllerIAMPolicy"

# Check if policy already exists
POLICY_ARN=$(aws iam list-policies --query "Policies[?PolicyName=='$POLICY_NAME'].Arn" --output text)

if [ -z "$POLICY_ARN" ]; then
    echo "Downloading IAM policy..."
    curl -o iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.7.0/docs/install/iam_policy.json
    
    echo "Creating IAM policy..."
    POLICY_ARN=$(aws iam create-policy \
        --policy-name $POLICY_NAME \
        --policy-document file://iam_policy.json \
        --query 'Policy.Arn' --output text)
    
    echo "✅ Policy created: $POLICY_ARN"
else
    echo "✅ Policy already exists: $POLICY_ARN"
fi

echo ""

# Step 2: Create IAM Role using IRSA (IAM Roles for Service Accounts)
echo "Step 2: Creating IAM Role with IRSA..."
echo ""

# Get OIDC provider
OIDC_PROVIDER=$(aws eks describe-cluster --name $CLUSTER_NAME --region $AWS_REGION --query "cluster.identity.oidc.issuer" --output text | sed -e "s/^https:\/\///")

echo "OIDC Provider: $OIDC_PROVIDER"

# Check if OIDC provider exists in IAM
OIDC_EXISTS=$(aws iam list-open-id-connect-providers --query "OpenIDConnectProviderList[?contains(Arn, '$OIDC_PROVIDER')].Arn" --output text)

if [ -z "$OIDC_EXISTS" ]; then
    echo "❌ OIDC provider not found in IAM. Creating..."
    eksctl utils associate-iam-oidc-provider --region=$AWS_REGION --cluster=$CLUSTER_NAME --approve
    echo "✅ OIDC provider created"
else
    echo "✅ OIDC provider already exists"
fi

echo ""

# Create IAM role and service account
echo "Creating ServiceAccount with IAM role..."

eksctl create iamserviceaccount \
  --cluster=$CLUSTER_NAME \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --role-name AmazonEKSLoadBalancerControllerRole \
  --attach-policy-arn=$POLICY_ARN \
  --approve \
  --override-existing-serviceaccounts \
  --region=$AWS_REGION

echo "✅ ServiceAccount created with IAM role"
echo ""

# Step 3: Install AWS Load Balancer Controller using Helm
echo "Step 3: Installing AWS Load Balancer Controller..."
echo ""

# Add EKS Helm repo
echo "Adding EKS Helm repository..."
helm repo add eks https://aws.github.io/eks-charts
helm repo update

echo ""

# Install or upgrade the controller
echo "Installing controller..."

helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=$CLUSTER_NAME \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=$AWS_REGION \
  --set vpcId=$VPC_ID \
  --set enableShield=false \
  --set enableWaf=false \
  --set enableWafv2=false

echo ""
echo "✅ AWS Load Balancer Controller installed"
echo ""

# Step 4: Verify installation
echo "Step 4: Verifying installation..."
echo ""

echo "Waiting for deployment to be ready..."
kubectl wait --for=condition=available --timeout=120s deployment/aws-load-balancer-controller -n kube-system

echo ""
echo "Controller status:"
kubectl get deployment -n kube-system aws-load-balancer-controller

echo ""
echo "Controller pods:"
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

echo ""
echo "======================================================"
echo "Installation Complete!"
echo "======================================================"
echo ""

echo "Next steps:"
echo "1. Apply your Ingress resources: kubectl apply -f pgvnext-ingress.yaml"
echo "2. Watch Ingress creation: kubectl get ingress --all-namespaces -w"
echo "3. Check ALB creation: aws elbv2 describe-load-balancers"
echo ""
