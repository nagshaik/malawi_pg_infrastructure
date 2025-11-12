# Install AWS Load Balancer Controller for EKS
# This script must be run after configuring kubectl to access the EKS cluster

param(
    [string]$ClusterName = "malawi-pg-azampay-eks-cluster",
    [string]$Region = "eu-central-1"
)

$ErrorActionPreference = "Stop"

Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "Installing AWS Load Balancer Controller" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host ""

# Get cluster information
Write-Host "Getting cluster information..." -ForegroundColor Yellow
$AccountId = aws sts get-caller-identity --query Account --output text
$VpcId = aws eks describe-cluster --name $ClusterName --region $Region --query "cluster.resourcesVpcConfig.vpcId" --output text

Write-Host "Cluster: $ClusterName" -ForegroundColor White
Write-Host "Region: $Region" -ForegroundColor White
Write-Host "Account: $AccountId" -ForegroundColor White
Write-Host "VPC: $VpcId" -ForegroundColor White
Write-Host ""

# Step 1: Create IAM Policy
Write-Host "Step 1: Creating IAM Policy..." -ForegroundColor Yellow
Write-Host ""

$PolicyName = "AWSLoadBalancerControllerIAMPolicy"
$PolicyArn = aws iam list-policies --query "Policies[?PolicyName=='$PolicyName'].Arn" --output text

if ([string]::IsNullOrEmpty($PolicyArn)) {
    Write-Host "Downloading IAM policy..." -ForegroundColor Gray
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.7.0/docs/install/iam_policy.json" -OutFile "iam_policy.json"
    
    Write-Host "Creating IAM policy..." -ForegroundColor Gray
    $PolicyArn = aws iam create-policy --policy-name $PolicyName --policy-document file://iam_policy.json --query 'Policy.Arn' --output text
    
    Write-Host "✅ Policy created: $PolicyArn" -ForegroundColor Green
} else {
    Write-Host "✅ Policy already exists: $PolicyArn" -ForegroundColor Green
}

Write-Host ""

# Step 2: Get OIDC Provider
Write-Host "Step 2: Checking OIDC Provider..." -ForegroundColor Yellow
Write-Host ""

$OidcIssuer = aws eks describe-cluster --name $ClusterName --region $Region --query "cluster.identity.oidc.issuer" --output text
$OidcProvider = $OidcIssuer -replace "https://", ""

Write-Host "OIDC Provider: $OidcProvider" -ForegroundColor White

$OidcExists = aws iam list-open-id-connect-providers --query "OpenIDConnectProviderList[?contains(Arn, '$OidcProvider')].Arn" --output text

if ([string]::IsNullOrEmpty($OidcExists)) {
    Write-Host "Creating OIDC provider..." -ForegroundColor Yellow
    
    # Check if eksctl is installed
    $eksctlInstalled = Get-Command eksctl -ErrorAction SilentlyContinue
    
    if ($eksctlInstalled) {
        eksctl utils associate-iam-oidc-provider --region=$Region --cluster=$ClusterName --approve
        Write-Host "✅ OIDC provider created" -ForegroundColor Green
    } else {
        Write-Host "❌ eksctl not found" -ForegroundColor Red
        Write-Host ""
        Write-Host "MANUAL STEP REQUIRED:" -ForegroundColor Yellow
        Write-Host "Enable OIDC provider in AWS Console:" -ForegroundColor White
        Write-Host "1. Go to EKS → Clusters → $ClusterName" -ForegroundColor White
        Write-Host "2. Go to Configuration → Details" -ForegroundColor White
        Write-Host "3. Enable OIDC provider" -ForegroundColor White
        Write-Host ""
        $continue = Read-Host "Press Enter after enabling OIDC provider..."
    }
} else {
    Write-Host "✅ OIDC provider already exists" -ForegroundColor Green
}

Write-Host ""

# Step 3: Create Service Account
Write-Host "Step 3: Creating Kubernetes ServiceAccount with IAM Role..." -ForegroundColor Yellow
Write-Host ""

$ServiceAccountName = "aws-load-balancer-controller"
$Namespace = "kube-system"
$RoleName = "AmazonEKSLoadBalancerControllerRole"

# Create trust policy
$TrustPolicy = @"
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${AccountId}:oidc-provider/${OidcProvider}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${OidcProvider}:sub": "system:serviceaccount:${Namespace}:${ServiceAccountName}",
          "${OidcProvider}:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
"@

$TrustPolicy | Out-File -FilePath "trust-policy.json" -Encoding UTF8

# Check if role exists
$RoleExists = aws iam get-role --role-name $RoleName --query 'Role.Arn' --output text 2>$null

if ([string]::IsNullOrEmpty($RoleExists)) {
    Write-Host "Creating IAM role..." -ForegroundColor Gray
    $RoleArn = aws iam create-role --role-name $RoleName --assume-role-policy-document file://trust-policy.json --query 'Role.Arn' --output text
    
    Write-Host "Attaching policy to role..." -ForegroundColor Gray
    aws iam attach-role-policy --role-name $RoleName --policy-arn $PolicyArn
    
    Write-Host "✅ IAM role created: $RoleArn" -ForegroundColor Green
} else {
    Write-Host "✅ IAM role already exists: $RoleExists" -ForegroundColor Green
    $RoleArn = $RoleExists
    
    # Ensure policy is attached
    aws iam attach-role-policy --role-name $RoleName --policy-arn $PolicyArn 2>$null
}

# Create Kubernetes ServiceAccount
Write-Host ""
Write-Host "Creating Kubernetes ServiceAccount..." -ForegroundColor Gray

$ServiceAccountYaml = @"
apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    app.kubernetes.io/component: controller
    app.kubernetes.io/name: aws-load-balancer-controller
  name: $ServiceAccountName
  namespace: $Namespace
  annotations:
    eks.amazonaws.com/role-arn: $RoleArn
"@

$ServiceAccountYaml | Out-File -FilePath "service-account.yaml" -Encoding UTF8
kubectl apply -f service-account.yaml

Write-Host "✅ ServiceAccount created" -ForegroundColor Green
Write-Host ""

# Step 4: Install AWS Load Balancer Controller using Helm
Write-Host "Step 4: Installing AWS Load Balancer Controller with Helm..." -ForegroundColor Yellow
Write-Host ""

# Check if Helm is installed
$helmInstalled = Get-Command helm -ErrorAction SilentlyContinue

if (-not $helmInstalled) {
    Write-Host "❌ Helm is not installed" -ForegroundColor Red
    Write-Host ""
    Write-Host "Install Helm from: https://helm.sh/docs/intro/install/" -ForegroundColor Yellow
    Write-Host "Or use: choco install kubernetes-helm" -ForegroundColor Yellow
    exit 1
}

Write-Host "Adding EKS Helm repository..." -ForegroundColor Gray
helm repo add eks https://aws.github.io/eks-charts
helm repo update

Write-Host ""
Write-Host "Installing controller..." -ForegroundColor Gray

helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller `
  -n $Namespace `
  --set clusterName=$ClusterName `
  --set serviceAccount.create=false `
  --set serviceAccount.name=$ServiceAccountName `
  --set region=$Region `
  --set vpcId=$VpcId `
  --set enableShield=false `
  --set enableWaf=false `
  --set enableWafv2=false

Write-Host ""
Write-Host "✅ AWS Load Balancer Controller installed" -ForegroundColor Green
Write-Host ""

# Step 5: Verify installation
Write-Host "Step 5: Verifying installation..." -ForegroundColor Yellow
Write-Host ""

Write-Host "Waiting for deployment to be ready..." -ForegroundColor Gray
Start-Sleep -Seconds 10

kubectl wait --for=condition=available --timeout=120s deployment/aws-load-balancer-controller -n $Namespace

Write-Host ""
Write-Host "Controller status:" -ForegroundColor White
kubectl get deployment -n $Namespace aws-load-balancer-controller

Write-Host ""
Write-Host "Controller pods:" -ForegroundColor White
kubectl get pods -n $Namespace -l app.kubernetes.io/name=aws-load-balancer-controller

Write-Host ""
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "Installation Complete!" -ForegroundColor Green
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Apply your Ingress resources:" -ForegroundColor White
Write-Host "   kubectl apply -f k8s-manifests/pgvnext-ingress.yaml" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Watch Ingress creation:" -ForegroundColor White
Write-Host "   kubectl get ingress --all-namespaces -w" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Check ALB creation:" -ForegroundColor White
Write-Host "   aws elbv2 describe-load-balancers" -ForegroundColor Gray
Write-Host ""

# Cleanup temp files
Remove-Item -Path "iam_policy.json" -ErrorAction SilentlyContinue
Remove-Item -Path "trust-policy.json" -ErrorAction SilentlyContinue
Remove-Item -Path "service-account.yaml" -ErrorAction SilentlyContinue
