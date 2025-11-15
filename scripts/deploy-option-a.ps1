# Deployment Script - Option A: API Gateway → Ingress ALB
# This script applies the new architecture without NLB

Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "Deploying Option A: CloudFront → API Gateway → ALB" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host ""

$ErrorActionPreference = "Stop"

# Step 1: Apply Ingress resources to create ALB
Write-Host "Step 1: Applying Ingress resources..." -ForegroundColor Yellow
Write-Host "This will create the internal ALB for the services" -ForegroundColor Gray
Write-Host ""

Write-Host "Checking EKS cluster connection..." -ForegroundColor Gray
try {
    $clusterName = aws eks list-clusters --query "clusters[0]" --output text
    Write-Host "✅ Connected to cluster: $clusterName" -ForegroundColor Green
    
    # Update kubeconfig
    aws eks update-kubeconfig --name $clusterName --region eu-central-1 2>$null
    
} catch {
    Write-Host "❌ Error: Cannot connect to EKS cluster" -ForegroundColor Red
    Write-Host "Please ensure you have AWS credentials configured" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "Applying Ingress resources from ../k8s-manifests/pgvnext-ingress.yaml..." -ForegroundColor Yellow
Write-Host "NOTE: This requires kubectl. If not installed, you need to apply manually." -ForegroundColor Yellow
Write-Host ""

# Check if kubectl is available
$kubectlAvailable = Get-Command kubectl -ErrorAction SilentlyContinue

if ($kubectlAvailable) {
    Write-Host "Applying Ingress..." -ForegroundColor Gray
    kubectl apply -f ../k8s-manifests/pgvnext-ingress.yaml
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Ingress resources applied successfully" -ForegroundColor Green
    } else {
        Write-Host "❌ Failed to apply Ingress" -ForegroundColor Red
        exit 1
    }
    
    Write-Host ""
    Write-Host "Waiting for ALB to be created (this takes 2-3 minutes)..." -ForegroundColor Yellow
    
    $maxWait = 180 # 3 minutes
    $waited = 0
    $albFound = $false
    
    while ($waited -lt $maxWait -and -not $albFound) {
        Start-Sleep -Seconds 10
        $waited += 10
        
        Write-Host "Checking ALB status... ($waited seconds)" -ForegroundColor Gray
        
        # Check if Ingress has an address (ALB DNS)
        $ingressAddress = kubectl get ingress pgvnext-checkout-api-ingress -n ns-pgvnext-checkout-api -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>$null
        
        if (![string]::IsNullOrEmpty($ingressAddress)) {
            Write-Host "✅ ALB created: $ingressAddress" -ForegroundColor Green
            $albFound = $true
        }
    }
    
    if (-not $albFound) {
        Write-Host "⚠️  ALB creation taking longer than expected" -ForegroundColor Yellow
        Write-Host "Check status with: kubectl get ingress --all-namespaces" -ForegroundColor Yellow
    }
    
} else {
    Write-Host "⚠️  kubectl not found" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "MANUAL STEPS REQUIRED:" -ForegroundColor Yellow
    Write-Host "1. Install kubectl or SSH to bastion" -ForegroundColor White
    Write-Host "2. Run: kubectl apply -f k8s-manifests/pgvnext-ingress.yaml" -ForegroundColor White
    Write-Host "3. Wait for ALB to be created (2-3 minutes)" -ForegroundColor White
    Write-Host "4. Verify: kubectl get ingress --all-namespaces" -ForegroundColor White
    Write-Host ""
    
    $continue = Read-Host "Have you applied the Ingress resources? (yes/no)"
    if ($continue -ne "yes") {
        Write-Host "Exiting. Please apply Ingress first." -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "Step 2: Removing old NLB resources from Terraform" -ForegroundColor Yellow
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Backing up old vpc-link.tf..." -ForegroundColor Gray
Copy-Item "vpc-link.tf" "vpc-link.tf.backup" -Force
Write-Host "✅ Backup created: vpc-link.tf.backup" -ForegroundColor Green

Write-Host ""
Write-Host "Renaming nlb.tf to nlb.tf.disabled..." -ForegroundColor Gray
if (Test-Path "nlb.tf") {
    Move-Item "nlb.tf" "nlb.tf.disabled" -Force
    Write-Host "✅ NLB configuration disabled" -ForegroundColor Green
}

Write-Host ""
Write-Host "Replacing vpc-link.tf with api-gateway-alb.tf..." -ForegroundColor Gray
Move-Item "vpc-link.tf" "vpc-link.tf.old" -Force
Move-Item "api-gateway-alb.tf" "vpc-link.tf" -Force
Write-Host "✅ API Gateway configuration updated" -ForegroundColor Green

Write-Host ""
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "Step 3: Applying Terraform changes" -ForegroundColor Yellow
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Initializing Terraform..." -ForegroundColor Gray
terraform init

Write-Host ""
Write-Host "Planning Terraform changes..." -ForegroundColor Yellow
terraform plan --var-file=dev.tfvars -out=tfplan

Write-Host ""
$apply = Read-Host "Apply Terraform changes? (yes/no)"

if ($apply -eq "yes") {
    Write-Host ""
    Write-Host "Applying Terraform..." -ForegroundColor Yellow
    terraform apply tfplan
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "✅ Terraform applied successfully" -ForegroundColor Green
    } else {
        Write-Host "❌ Terraform apply failed" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "Skipping Terraform apply" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "Deployment Complete!" -ForegroundColor Green
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "New Architecture:" -ForegroundColor Cyan
Write-Host "  Internet → CloudFront → API Gateway → VPC Link → Ingress ALB → EKS Services" -ForegroundColor White
Write-Host ""

# Get CloudFront domain
$cloudfrontDomain = terraform output -raw cloudfront_distribution_domain 2>$null
if (![string]::IsNullOrEmpty($cloudfrontDomain)) {
    Write-Host "CloudFront Endpoint:" -ForegroundColor Cyan
    Write-Host "  https://$cloudfrontDomain" -ForegroundColor White
    Write-Host ""
    
    Write-Host "Test endpoints:" -ForegroundColor Cyan
    Write-Host "  curl https://$cloudfrontDomain/core/health" -ForegroundColor White
    Write-Host "  curl https://$cloudfrontDomain/checkout/health" -ForegroundColor White
    Write-Host "  curl https://$cloudfrontDomain/auth/health" -ForegroundColor White
}

Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Wait 2-3 minutes for all resources to stabilize" -ForegroundColor White
Write-Host "2. Test CloudFront endpoints above" -ForegroundColor White
Write-Host "3. Check ALB targets: kubectl get ingress --all-namespaces" -ForegroundColor White
Write-Host "4. Monitor logs: aws logs tail /aws/apigateway/malawi-pg-eks-http-api --follow" -ForegroundColor White
Write-Host ""
