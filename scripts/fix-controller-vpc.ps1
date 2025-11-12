# Script to fix AWS Load Balancer Controller VPC configuration
# Adds --aws-vpc-id and --cluster-name flags to the controller deployment

$CLUSTER_NAME = "malawi-pg-azampay-eks-cluster"
$VPC_ID = "vpc-077eae864604eac3a"
$REGION = "eu-central-1"

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Fixing AWS Load Balancer Controller Configuration" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Cluster: $CLUSTER_NAME" -ForegroundColor Yellow
Write-Host "VPC ID: $VPC_ID" -ForegroundColor Yellow
Write-Host "Region: $REGION" -ForegroundColor Yellow
Write-Host ""

# Get current deployment
Write-Host "Getting current controller deployment..." -ForegroundColor Green
kubectl get deployment aws-load-balancer-controller -n kube-system -o yaml | Out-File -FilePath controller-backup.yaml
Write-Host "Backup saved to controller-backup.yaml" -ForegroundColor Gray
Write-Host ""

# Update the controller deployment with VPC ID argument
Write-Host "Patching controller deployment with VPC ID and region..." -ForegroundColor Green

$patchJson = @"
{
  "spec": {
    "template": {
      "spec": {
        "containers": [
          {
            "name": "controller",
            "args": [
              "--cluster-name=$CLUSTER_NAME",
              "--aws-vpc-id=$VPC_ID",
              "--aws-region=$REGION",
              "--ingress-class=alb"
            ]
          }
        ]
      }
    }
  }
}
"@

$patchJson | kubectl patch deployment aws-load-balancer-controller -n kube-system --patch-file=/dev/stdin

Write-Host ""
Write-Host "Waiting for controller to restart..." -ForegroundColor Green
kubectl rollout status deployment/aws-load-balancer-controller -n kube-system --timeout=120s

Write-Host ""
Write-Host "Sleeping 10 seconds for controller to initialize..." -ForegroundColor Gray
Start-Sleep -Seconds 10

Write-Host ""
Write-Host "Checking controller logs..." -ForegroundColor Green
kubectl logs -n kube-system deployment/aws-load-balancer-controller --tail=30

Write-Host ""
Write-Host "Checking controller status..." -ForegroundColor Green
kubectl get deployment -n kube-system aws-load-balancer-controller

Write-Host ""
Write-Host "Checking Ingress resources..." -ForegroundColor Green
kubectl get ingress --all-namespaces

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Fix applied! Monitor ADDRESS column for ALB creation." -ForegroundColor Cyan
Write-Host "Run: kubectl get ingress --all-namespaces -w" -ForegroundColor Yellow
Write-Host "==================================================" -ForegroundColor Cyan
