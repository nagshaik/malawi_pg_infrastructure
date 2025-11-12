# Quick Fix Guide - 503 Error Resolution

## Problem
CloudFront returns 503 because the Ingress ALB hasn't been created yet.

## Root Cause
The Ingress resources in `pgvnext-ingress.yaml` need to be applied to the EKS cluster.

## Solution Steps

### 1. Copy Ingress YAML to Bastion
From your local machine:
```powershell
# Get bastion IP
cd c:\Users\nagin\malawi-pg-infra\eks
$bastionIp = terraform output -raw bastion_eip_public_ip

# Copy the Ingress file
scp k8s-manifests/pgvnext-ingress.yaml ubuntu@${bastionIp}:/home/ubuntu/
```

### 2. SSH to Bastion and Apply
```bash
ssh ubuntu@<bastion-ip>

# Verify kubectl works
kubectl get nodes

# Apply the Ingress resources
kubectl apply -f pgvnext-ingress.yaml

# Verify Ingress was created
kubectl get ingress --all-namespaces

# Wait for ALB to be provisioned (takes 2-3 minutes)
kubectl get ingress --all-namespaces -w
```

### 3. Verify ALB Creation
After applying, check if the ALB is being created:

```bash
# Check Ingress status
kubectl describe ingress pgvnext-checkout-api-ingress -n ns-pgvnext-checkout-api

# Should show ALB DNS name in the Address field
kubectl get ingress --all-namespaces -o wide
```

From your local machine:
```powershell
# Check if ALB exists now
aws elbv2 describe-load-balancers --query "LoadBalancers[?contains(LoadBalancerName, 'k8s')].{Name:LoadBalancerName,DNS:DNSName,State:State.Code,Scheme:Scheme}" --output table
```

### 4. Update NLB Target
Once the ALB is created, you need to register it as a target in your NLB.

**Option A: Manual (Quick)**
```bash
# Get the ALB ARN
ALB_ARN=$(aws elbv2 describe-load-balancers --query "LoadBalancers[?contains(LoadBalancerName, 'k8s-pgvnext')].LoadBalancerArn" --output text)

# Get NLB target group ARN
NLB_TG_ARN=$(aws elbv2 describe-target-groups --query "TargetGroups[?contains(TargetGroupName, 'malawi-pg-eks-http')].TargetGroupArn" --output text)

# Register ALB with NLB (this won't work - NLB can't target ALB directly)
# Instead, we need to update the architecture
```

## Architecture Issue Found!

The current setup has:
- CloudFront → API Gateway → VPC Link → **NLB** → (nothing)
- Ingress → **ALB** → Services

**Problem**: NLB and ALB are separate. API Gateway routes to NLB, but Ingress creates ALB.

## Correct Solution

We have two options:

### Option 1: Remove NLB, Route API Gateway Directly to ALB (Recommended)
Update API Gateway integration to point to the Ingress ALB instead of the NLB.

### Option 2: Keep NLB, Update Ingress to Use NLB
Change the Ingress to use `alb.ingress.kubernetes.io/target-type: instance` and configure NLB as the load balancer.

---

## Immediate Fix (Option 1 - Route to ALB)

1. **Apply Ingress** (creates ALB)
2. **Update API Gateway integration** to point to ALB instead of NLB
3. **Remove or repurpose NLB**

Would you like me to:
A) Update the Terraform to route API Gateway → ALB directly (remove NLB)
B) Update the Ingress to work with the existing NLB
C) Keep both and manually link them?
