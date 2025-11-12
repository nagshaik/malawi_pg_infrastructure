#!/bin/bash
# Manual Installation of AWS Load Balancer Controller from Bastion
# Run this script on the bastion host with kubectl access

set -e

echo "======================================================"
echo "Installing AWS Load Balancer Controller"
echo "======================================================"
echo ""

# Variables
CLUSTER_NAME="malawi-pg-azampay-eks-cluster"
AWS_REGION="eu-central-1"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "Cluster: $CLUSTER_NAME"
echo "Region: $AWS_REGION"
echo "Account: $AWS_ACCOUNT_ID"
echo ""

# Step 1: Download IAM Policy
echo "Step 1: Creating IAM Policy..."
echo ""

cd /tmp

curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.7.0/docs/install/iam_policy.json

POLICY_NAME="AWSLoadBalancerControllerIAMPolicy"

# Check if policy exists
POLICY_ARN=$(aws iam list-policies --query "Policies[?PolicyName=='$POLICY_NAME'].Arn" --output text)

if [ -z "$POLICY_ARN" ]; then
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

# Step 2: Get OIDC Provider
echo "Step 2: Checking OIDC Provider..."
echo ""

OIDC_PROVIDER=$(aws eks describe-cluster --name $CLUSTER_NAME --region $AWS_REGION --query "cluster.identity.oidc.issuer" --output text | sed -e "s/^https:\/\///")

echo "OIDC Provider: $OIDC_PROVIDER"

# Check if OIDC provider exists in IAM
OIDC_EXISTS=$(aws iam list-open-id-connect-providers --query "OpenIDConnectProviderList[?contains(Arn, '$OIDC_PROVIDER')].Arn" --output text)

if [ -z "$OIDC_EXISTS" ]; then
    echo "Creating OIDC provider..."
    
    # Get OIDC thumbprint
    THUMBPRINT=$(echo | openssl s_client -servername oidc.eks.$AWS_REGION.amazonaws.com -showcerts -connect oidc.eks.$AWS_REGION.amazonaws.com:443 2>&- | tail -r | sed -n '/-----END CERTIFICATE-----/,/-----BEGIN CERTIFICATE-----/p; /-----BEGIN CERTIFICATE-----/q' | tail -r | openssl x509 -fingerprint -noout | sed 's/://g' | awk -F= '{print tolower($2)}')
    
    # Create OIDC provider
    aws iam create-open-id-connect-provider \
        --url https://$OIDC_PROVIDER \
        --client-id-list sts.amazonaws.com \
        --thumbprint-list $THUMBPRINT
    
    echo "✅ OIDC provider created"
else
    echo "✅ OIDC provider already exists"
fi

echo ""

# Step 3: Create IAM Role for Service Account
echo "Step 3: Creating IAM Role for Service Account..."
echo ""

ROLE_NAME="AmazonEKSLoadBalancerControllerRole"

# Create trust policy
cat > trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/${OIDC_PROVIDER}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${OIDC_PROVIDER}:sub": "system:serviceaccount:kube-system:aws-load-balancer-controller",
          "${OIDC_PROVIDER}:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
EOF

# Check if role exists
ROLE_ARN=$(aws iam get-role --role-name $ROLE_NAME --query 'Role.Arn' --output text 2>/dev/null || echo "")

if [ -z "$ROLE_ARN" ]; then
    echo "Creating IAM role..."
    ROLE_ARN=$(aws iam create-role \
        --role-name $ROLE_NAME \
        --assume-role-policy-document file://trust-policy.json \
        --query 'Role.Arn' --output text)
    
    echo "Attaching policy to role..."
    aws iam attach-role-policy \
        --role-name $ROLE_NAME \
        --policy-arn $POLICY_ARN
    
    echo "✅ IAM role created: $ROLE_ARN"
else
    echo "✅ IAM role already exists: $ROLE_ARN"
    
    # Ensure policy is attached
    aws iam attach-role-policy \
        --role-name $ROLE_NAME \
        --policy-arn $POLICY_ARN 2>/dev/null || true
fi

echo ""

# Step 4: Create Kubernetes Service Account
echo "Step 4: Creating Kubernetes Service Account..."
echo ""

cat > aws-load-balancer-controller-service-account.yaml <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    app.kubernetes.io/component: controller
    app.kubernetes.io/name: aws-load-balancer-controller
  name: aws-load-balancer-controller
  namespace: kube-system
  annotations:
    eks.amazonaws.com/role-arn: $ROLE_ARN
EOF

kubectl apply -f aws-load-balancer-controller-service-account.yaml

echo "✅ Service Account created"
echo ""

# Step 5: Install cert-manager (required for webhook certificates)
echo "Step 5: Installing cert-manager..."
echo ""

# Check if cert-manager is already installed
if kubectl get namespace cert-manager >/dev/null 2>&1; then
    echo "✅ cert-manager already installed"
else
    echo "Installing cert-manager..."
    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
    
    echo "Waiting for cert-manager to be ready..."
    kubectl wait --for=condition=available --timeout=120s deployment/cert-manager -n cert-manager
    kubectl wait --for=condition=available --timeout=120s deployment/cert-manager-cainjector -n cert-manager
    kubectl wait --for=condition=available --timeout=120s deployment/cert-manager-webhook -n cert-manager
    
    echo "✅ cert-manager installed"
fi

echo ""

# Step 6: Download and apply AWS Load Balancer Controller
echo "Step 6: Installing AWS Load Balancer Controller..."
echo ""

# Download controller YAML
curl -Lo v2_7_0_full.yaml https://github.com/kubernetes-sigs/aws-load-balancer-controller/releases/download/v2.7.0/v2_7_0_full.yaml

# Get VPC ID
VPC_ID=$(aws eks describe-cluster --name $CLUSTER_NAME --region $AWS_REGION --query "cluster.resourcesVpcConfig.vpcId" --output text)

# Modify the YAML to set cluster name, region, and VPC
sed -i "s/your-cluster-name/$CLUSTER_NAME/g" v2_7_0_full.yaml
sed -i "s/# - --aws-region=.*/    - --aws-region=$AWS_REGION/g" v2_7_0_full.yaml
sed -i "s/# - --aws-vpc-id=.*/    - --aws-vpc-id=$VPC_ID/g" v2_7_0_full.yaml

# Apply the controller (this will create everything including a ServiceAccount without IAM role)
kubectl apply -f v2_7_0_full.yaml

# Replace the ServiceAccount with our version that has the IAM role annotation
echo "Replacing ServiceAccount with IAM role annotation..."
kubectl delete serviceaccount aws-load-balancer-controller -n kube-system --ignore-not-found=true
sleep 2
kubectl apply -f aws-load-balancer-controller-service-account.yaml

# Restart the controller deployment to pick up the new ServiceAccount
echo "Restarting controller to use new ServiceAccount..."
kubectl rollout restart deployment aws-load-balancer-controller -n kube-system

echo ""
echo "Waiting for controller to be ready..."
sleep 10

kubectl wait --for=condition=available --timeout=120s deployment/aws-load-balancer-controller -n kube-system 2>/dev/null || true

echo ""
echo "✅ AWS Load Balancer Controller installed"
echo ""

# Step 7: Verify installation
echo "Step 7: Verifying installation..."
echo ""

echo "Controller deployment:"
kubectl get deployment -n kube-system aws-load-balancer-controller

echo ""
echo "Controller pods:"
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

echo ""
echo "Controller logs (last 10 lines):"
kubectl logs -n kube-system deployment/aws-load-balancer-controller --tail=10

echo ""
echo "======================================================"
echo "Installation Complete!"
echo "======================================================"
echo ""

echo "Next steps:"
echo "1. Apply your Ingress resources:"
echo "   kubectl apply -f pgvnext-ingress.yaml"
echo ""
echo "2. Watch Ingress creation:"
echo "   kubectl get ingress --all-namespaces -w"
echo ""
echo "3. Verify ALB creation:"
echo "   aws elbv2 describe-load-balancers --query \"LoadBalancers[?contains(LoadBalancerName, 'k8s')]\""
echo ""

# Cleanup temp files
rm -f iam_policy.json trust-policy.json aws-load-balancer-controller-service-account.yaml v2_7_0_full.yaml
