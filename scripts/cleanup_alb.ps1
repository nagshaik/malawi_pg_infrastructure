Write-Host "AWS Load Balancer Controller and Ingress Cleanup Script"
Write-Host "================================================="
Write-Host "This script will uninstall the AWS Load Balancer Controller Helm release, delete ingress and ingressclass,"
Write-Host "and optionally help identify related AWS resources for cleanup."
Write-Host ""

# Function to run kubectl commands safely
function Invoke-KubectlSafe {
    param([string]$cmd)
    try {
        Invoke-Expression "kubectl $cmd"
    }
    catch {
        Write-Warning "Command failed: kubectl $cmd"
        Write-Warning $_.Exception.Message
    }
}

Write-Host "1) Removing AWS Load Balancer Controller Helm Release"
Invoke-KubectlSafe "delete deployment -n kube-system aws-load-balancer-controller --ignore-not-found"

Write-Host "`n2) Removing AWS Load Balancer Controller ServiceAccount"
Invoke-KubectlSafe "delete serviceaccount -n kube-system aws-load-balancer-controller --ignore-not-found"

Write-Host "`n3) Delete example ingress and ingressclass (if present)"
Invoke-KubectlSafe "delete ingress example-ingress --ignore-not-found"
Invoke-KubectlSafe "delete ingressclass alb --ignore-not-found"

Write-Host "`n4) (Optional) Remove ALB-related security groups and target groups"
Write-Host "Please check AWS Console manually for:"
Write-Host "- Security Groups with names containing 'ingress' or 'alb'"
Write-Host "- Target Groups that are no longer needed"

Write-Host "`n5) (Optional) IAM cleanup — searching for ALB controller roles/policies"
$rolePattern = "*alb*controller*"

Write-Host "`nPotentially related IAM roles:"
aws iam list-roles --query "Roles[?contains(RoleName, 'alb') || contains(RoleName, 'load-balancer')].RoleName" --output text

Write-Host "`nNext steps:"
Write-Host "1. Verify the cleanup in your AWS Console"
Write-Host "2. Check for any remaining Load Balancers in EC2 > Load Balancing"
Write-Host "3. Review and delete any unused Target Groups"
Write-Host "4. Check for any remaining security groups"
Write-Host "5. Review and clean up any identified IAM roles and policies"