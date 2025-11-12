# Step-by-Step Guide: Deploy Option A (API Gateway → ALB)

## Overview
Remove NLB from the architecture and route API Gateway directly to the Ingress ALB.

**New Architecture:**
```
Internet → CloudFront → API Gateway → VPC Link → Ingress ALB → EKS Pods
```

---

## Step 1: Apply Ingress Resources (Create ALB)

### Option 1A: If kubectl is installed locally
```powershell
# Update kubeconfig
aws eks update-kubeconfig --name malawi-pg-azampay-eks-cluster --region eu-central-1

# Apply Ingress
cd c:\Users\nagin\malawi-pg-infra
kubectl apply -f k8s-manifests/pgvnext-ingress.yaml

# Verify Ingress creation
kubectl get ingress --all-namespaces

# Wait for ALB (shows ADDRESS column populated)
kubectl get ingress --all-namespaces -w
```

### Option 1B: Via Bastion (if kubectl not local)
```powershell
# Get bastion IP
aws ec2 describe-instances --filters "Name=tag:Name,Values=*bastion*" --query "Reservations[0].Instances[0].PublicIpAddress" --output text

# Copy Ingress file
scp k8s-manifests/pgvnext-ingress.yaml ubuntu@<BASTION-IP>:/home/ubuntu/

# SSH and apply
ssh ubuntu@<BASTION-IP>
kubectl apply -f pgvnext-ingress.yaml
kubectl get ingress --all-namespaces
```

**Expected Output:**
```
NAMESPACE                                    NAME                             CLASS   HOSTS   ADDRESS
ns-pgvnext-checkout-api                      pgvnext-checkout-api-ingress     alb     *       k8s-pgvnext-...elb.amazonaws.com
ns-pgvnext-checkout-background-service       pgvnext-checkout-bg-ingress      alb     *       k8s-pgvnext-...elb.amazonaws.com
...
```

**Wait 2-3 minutes** for ALB to be fully provisioned.

---

## Step 2: Get ALB Details

```powershell
# Find the ALB created by Ingress Controller
aws elbv2 describe-load-balancers --query "LoadBalancers[?contains(LoadBalancerName, 'k8s-pgvnext')].{Name:LoadBalancerName,ARN:LoadBalancerArn,DNS:DNSName,Scheme:Scheme}" --output table

# Save the ALB ARN (you'll need it)
$ALB_ARN = (aws elbv2 describe-load-balancers --query "LoadBalancers[?contains(LoadBalancerName, 'k8s-pgvnext')].LoadBalancerArn" --output text)

echo $ALB_ARN

# Get ALB HTTP listener ARN
$LISTENER_ARN = (aws elbv2 describe-listeners --load-balancer-arn $ALB_ARN --query "Listeners[?Port==\`80\`].ListenerArn" --output text)

echo $LISTENER_ARN
```

---

## Step 3: Update API Gateway Integration (Manual)

Since Terraform can't reference the ALB until it exists, we'll update the integration manually first:

```powershell
cd c:\Users\nagin\malawi-pg-infra\eks

# Get current integration ID
$API_ID = (terraform output -raw api_gateway_id)
$INTEGRATION_ID = (aws apigatewayv2 get-integrations --api-id $API_ID --query "Items[0].IntegrationId" --output text)

# Get VPC Link ID
$VPC_LINK_ID = (terraform output -raw vpc_link_id)

# Get ALB listener ARN (from Step 2)
$LISTENER_ARN = (aws elbv2 describe-listeners --load-balancer-arn $ALB_ARN --query "Listeners[?Port==\`80\`].ListenerArn" --output text)

# Update the integration to point to ALB
aws apigatewayv2 update-integration `
  --api-id $API_ID `
  --integration-id $INTEGRATION_ID `
  --integration-uri $LISTENER_ARN

# Deploy the API
aws apigatewayv2 create-deployment --api-id $API_ID --stage-name '$default'
```

---

## Step 4: Test the New Route

```powershell
# Get CloudFront domain
$CF_DOMAIN = (terraform output -raw cloudfront_distribution_domain)

# Test endpoints
curl -v "https://$CF_DOMAIN/core/health"
curl -v "https://$CF_DOMAIN/checkout/health"
curl -v "https://$CF_DOMAIN/auth/health"
```

**Expected:** Status 200/404 (depending on service health endpoint), NOT 503

---

## Step 5: Update Terraform Configuration (Optional - for state management)

Once everything is working, you can update Terraform to manage the ALB reference:

### 5a: Disable NLB resources

```powershell
cd c:\Users\nagin\malawi-pg-infra\eks

# Rename nlb.tf to prevent Terraform from managing it
Move-Item nlb.tf nlb.tf.disabled -Force
```

### 5b: Import ALB into Terraform state (optional)

```powershell
# Create a data source for the ALB
# Add this to a new file: eks/data-alb.tf
```

Create `eks/data-alb.tf`:
```terraform
# Data source to reference the Ingress ALB
data "aws_lb" "ingress_alb" {
  name = "k8s-pgvnextsharedalb-..."  # Replace with actual ALB name from Step 2
}

data "aws_lb_listener" "ingress_alb_http" {
  load_balancer_arn = data.aws_lb.ingress_alb.arn
  port              = 80
}

# Output the ALB details
output "ingress_alb_dns" {
  value = data.aws_lb.ingress_alb.dns_name
}

output "ingress_alb_arn" {
  value = data.aws_lb.ingress_alb.arn
}
```

---

## Step 6: Verify Everything Works

### Check ALB Targets
```powershell
# Get target groups for the ALB
aws elbv2 describe-target-groups --load-balancer-arn $ALB_ARN --query "TargetGroups[*].{Name:TargetGroupName,Port:Port,Healthy:HealthCheckPath}" --output table

# Check target health
$TG_ARNS = (aws elbv2 describe-target-groups --load-balancer-arn $ALB_ARN --query "TargetGroups[*].TargetGroupArn" --output text)

foreach ($tg in $TG_ARNS -split " ") {
    Write-Host "Target Group: $tg"
    aws elbv2 describe-target-health --target-group-arn $tg --output table
}
```

### Check API Gateway Logs
```powershell
# Tail API Gateway logs
aws logs tail /aws/apigateway/malawi-pg-eks-http-api --since 5m --follow
```

### Run Full Test
```powershell
# Run the test script
..\scripts\test-cloudfront-routing.ps1
```

---

## Troubleshooting

### If you get 503 errors:
1. Check ALB exists: `aws elbv2 describe-load-balancers`
2. Check ALB targets are healthy: `aws elbv2 describe-target-health --target-group-arn <TG_ARN>`
3. Check API Gateway integration: `aws apigatewayv2 get-integration --api-id $API_ID --integration-id $INTEGRATION_ID`
4. Check VPC Link status: `aws apigatewayv2 get-vpc-link --vpc-link-id $VPC_LINK_ID`

### If ALB not created:
1. Check Ingress status: `kubectl describe ingress pgvnext-checkout-api-ingress -n ns-pgvnext-checkout-api`
2. Check AWS Load Balancer Controller logs: `kubectl logs -n kube-system deployment/aws-load-balancer-controller`
3. Verify IAM permissions for Load Balancer Controller

### If targets unhealthy:
1. Check pod status: `kubectl get pods --all-namespaces | Select-String pgvnext`
2. Check service endpoints: `kubectl get endpoints -n ns-pgvnext-checkout-api`
3. Verify security groups allow traffic from ALB to pods

---

## Rollback (if needed)

```powershell
# Restore NLB configuration
cd c:\Users\nagin\malawi-pg-infra\eks
Move-Item nlb.tf.disabled nlb.tf -Force

# Delete Ingress resources
kubectl delete -f k8s-manifests/pgvnext-ingress.yaml

# Reset API Gateway integration
terraform apply --var-file=dev.tfvars
```

---

## Summary

✅ **Step 1**: Apply Ingress → Creates ALB  
✅ **Step 2**: Get ALB ARN and Listener ARN  
✅ **Step 3**: Update API Gateway integration manually  
✅ **Step 4**: Test via CloudFront  
✅ **Step 5**: Update Terraform (optional)  
✅ **Step 6**: Verify and monitor  

The architecture is now: **CloudFront → API Gateway → Ingress ALB → EKS Services**
