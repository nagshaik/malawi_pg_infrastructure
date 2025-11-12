# Connecting Ingress ALB to CloudFront - Complete Setup Guide

## Architecture Overview

```
Internet → CloudFront (d3d9sb62vwrxui.cloudfront.net)
           ↓
        API Gateway (Private)
           ↓
        VPC Link
           ↓
        ALB (created by Ingress Controller)
           ↓
        EKS Pods (7 pgvnext services)
```

## Step-by-Step Setup

### Step 1: Install AWS Load Balancer Controller (On Bastion)

```bash
# Upload and run the installation script
cd /tmp
./install-alb-controller-manual.sh
```

**What this does:**
- Creates IAM policy and role for the controller
- Sets up OIDC provider for IRSA (IAM Roles for Service Accounts)
- Installs cert-manager (required for webhook certificates)
- Deploys AWS Load Balancer Controller to kube-system namespace

**Verify:**
```bash
kubectl get deployment -n kube-system aws-load-balancer-controller
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
```

---

### Step 2: Apply Ingress Resources (Creates ALB)

```bash
# Apply the Ingress manifests
kubectl apply -f pgvnext-ingress.yaml

# Watch the Ingress creation (wait for ADDRESS column)
kubectl get ingress --all-namespaces -w
```

**What happens:**
- AWS Load Balancer Controller watches for Ingress resources
- Controller creates an internal ALB in private subnets
- ALB is configured with:
  - Shared name: `k8s-pgvnext-shared-alb-*`
  - Scheme: internal
  - Target type: IP (routes directly to pod IPs)
  - 7 target groups (one per service)
  - Path-based routing rules

**Expected output:**
```
NAMESPACE            NAME                          CLASS   HOSTS   ADDRESS                                    PORTS   AGE
ns-pgvnext-checkout-api   pgvnext-checkout-api-ingress   <none>  *   k8s-pgvnext-pgvnexts-abc123-1234567890.eu-central-1.elb.amazonaws.com   80   2m
```

**Verify ALB creation:**
```bash
# List ALBs with "k8s-pgvnext" in the name
aws elbv2 describe-load-balancers \
  --query "LoadBalancers[?contains(LoadBalancerName, 'k8s-pgvnext')].{Name:LoadBalancerName,DNS:DNSName,Scheme:Scheme,VPC:VpcId}" \
  --output table

# Get ALB ARN and Listener ARN (save these!)
ALB_ARN=$(aws elbv2 describe-load-balancers \
  --query "LoadBalancers[?contains(LoadBalancerName, 'k8s-pgvnext')].LoadBalancerArn" \
  --output text)

LISTENER_ARN=$(aws elbv2 describe-listeners \
  --load-balancer-arn $ALB_ARN \
  --query "Listeners[?Port==\`80\`].ListenerArn" \
  --output text)

echo "ALB ARN: $ALB_ARN"
echo "Listener ARN: $LISTENER_ARN"
```

---

### Step 3: Update API Gateway Integration (Connect to ALB)

The API Gateway was created by Terraform but references the ALB that didn't exist yet. Now we update it manually:

```bash
# Get API Gateway ID from Terraform
cd /path/to/eks
API_ID=$(terraform output -raw api_gateway_id)

# Get current integration ID
INTEGRATION_ID=$(aws apigatewayv2 get-integrations \
  --api-id $API_ID \
  --query "Items[0].IntegrationId" \
  --output text)

echo "API Gateway ID: $API_ID"
echo "Integration ID: $INTEGRATION_ID"
echo "Target Listener: $LISTENER_ARN"

# Update the integration to point to ALB listener
aws apigatewayv2 update-integration \
  --api-id $API_ID \
  --integration-id $INTEGRATION_ID \
  --integration-uri $LISTENER_ARN \
  --connection-type VPC_LINK

# Deploy the changes to $default stage
aws apigatewayv2 create-deployment \
  --api-id $API_ID \
  --stage-name '$default'

echo "✅ API Gateway updated to route to ALB"
```

**What this does:**
- Updates API Gateway integration from placeholder to actual ALB listener ARN
- Routes all API Gateway requests to ALB port 80
- ALB then routes based on path:
  - `/checkout` → Checkout API pods
  - `/callback` → Callback service pods
  - `/consumer` → Consumer API pods
  - `/c2b` → Core API pods
  - `/admin` → Admin Portal pods
  - `/adminservice` → Admin Service pods
  - `/authenticator` → Authenticator pods

---

### Step 4: Test End-to-End Flow

```bash
# Test via CloudFront (this is the public endpoint)
curl -v "https://d3d9sb62vwrxui.cloudfront.net/checkout/health"
curl -v "https://d3d9sb62vwrxui.cloudfront.net/c2b/health"
curl -v "https://d3d9sb62vwrxui.cloudfront.net/admin/health"

# Expected: 200 OK or 404 (depending on if /health exists in your apps)
# Should NOT be 503 anymore!

# Verify CloudFront headers are present
curl -I "https://d3d9sb62vwrxui.cloudfront.net/checkout/health" | grep -i "x-cache\|x-amz-cf"
```

**Test direct API Gateway access (should fail with 403):**
```bash
# Get API Gateway endpoint
API_ENDPOINT=$(aws apigatewayv2 get-apis \
  --query "Items[?Name=='pgvnext-http-api'].ApiEndpoint" \
  --output text)

# Try to access directly (without CloudFront header)
curl -v "$API_ENDPOINT/checkout/health"

# Expected: 403 Forbidden (Lambda authorizer blocks it)
```

---

### Step 5: Verify ALB Target Health

```bash
# Get all target groups for the ALB
aws elbv2 describe-target-groups \
  --load-balancer-arn $ALB_ARN \
  --query "TargetGroups[*].{Name:TargetGroupName,Port:Port,Protocol:Protocol,HealthCheckPath:HealthCheckPath}" \
  --output table

# Check health of targets in each group
for TG_ARN in $(aws elbv2 describe-target-groups --load-balancer-arn $ALB_ARN --query "TargetGroups[*].TargetGroupArn" --output text); do
  echo "Target Group: $TG_ARN"
  aws elbv2 describe-target-health --target-group-arn $TG_ARN --output table
  echo ""
done
```

**Expected:** All targets should show `State: healthy`

**If unhealthy:**
```bash
# Check if pods are running
kubectl get pods --all-namespaces | grep pgvnext

# Check pod logs
kubectl logs -n ns-pgvnext-checkout-api <pod-name>

# Check if service endpoints exist
kubectl get endpoints -n ns-pgvnext-checkout-api prod-pgvnext-checkout-api-app-service
```

---

### Step 6: Configure Custom Domain (Optional)

If you want to use your own domain from the other AWS account:

**In the domain owner's AWS account (Route 53):**
```bash
# Create CNAME record pointing to CloudFront
example.com → CNAME → d3d9sb62vwrxui.cloudfront.net
```

**In your AWS account (CloudFront):**
1. Request ACM certificate for `example.com` in **us-east-1** (CloudFront requirement)
2. Validate certificate via DNS or email
3. Update CloudFront distribution:
   ```bash
   # Add alternate domain name
   aws cloudfront update-distribution \
     --id <DISTRIBUTION_ID> \
     --distribution-config file://cloudfront-config.json
   ```

**Configuration for CloudFront:**
```json
{
  "Aliases": {
    "Quantity": 1,
    "Items": ["example.com"]
  },
  "ViewerCertificate": {
    "ACMCertificateArn": "arn:aws:acm:us-east-1:...:certificate/...",
    "SSLSupportMethod": "sni-only",
    "MinimumProtocolVersion": "TLSv1.2_2021"
  }
}
```

---

## Path Routing Examples

Once everything is connected, your URLs will work like this:

| Public URL | Routes Through | Target Service | Backend Path |
|-----------|----------------|----------------|--------------|
| `https://example.com/checkout` | CloudFront → API Gateway → ALB | Checkout API | `/checkout/*` |
| `https://example.com/callback` | CloudFront → API Gateway → ALB | Checkout Background | `/callback/*` |
| `https://example.com/consumer` | CloudFront → API Gateway → ALB | Consumer API | `/consumer/*` |
| `https://example.com/c2b` | CloudFront → API Gateway → ALB | Core API | `/c2b/*` |
| `https://example.com/admin` | CloudFront → API Gateway → ALB | Admin Portal | `/admin/*` |
| `https://example.com/adminservice` | CloudFront → API Gateway → ALB | Admin Service | `/adminservice/*` |
| `https://example.com/authenticator` | CloudFront → API Gateway → ALB | Authenticator | `/authenticator/*` |

---

## Troubleshooting

### Issue: Ingress stuck in "creating" state
```bash
# Check controller logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller --tail=50

# Check Ingress events
kubectl describe ingress -n ns-pgvnext-checkout-api pgvnext-checkout-api-ingress
```

### Issue: ALB created but targets unhealthy
```bash
# Check pod status
kubectl get pods --all-namespaces | grep pgvnext

# Check if pods are receiving traffic
kubectl logs -n ns-pgvnext-checkout-api <pod-name> --tail=100

# Check security groups (ALB → Pod traffic)
aws ec2 describe-security-groups --group-ids <ALB_SG> <POD_SG>
```

### Issue: 502 Bad Gateway from CloudFront
```bash
# Check API Gateway logs
aws logs tail /aws/apigateway/pgvnext-http-api --follow

# Check VPC Link status
aws apigatewayv2 get-vpc-links --query "Items[?Name=='alb_vpc_link'].VpcLinkStatus"
```

### Issue: 503 Service Unavailable
- ALB not connected to API Gateway (complete Step 3)
- ALB target groups have no healthy targets (check Step 5)
- Services not running in EKS (check pods)

---

## Cleanup Old Resources

After confirming ALB works, remove the old NLB:

```bash
cd /path/to/eks

# Disable NLB Terraform config
mv nlb.tf nlb.tf.disabled

# Apply to destroy NLB
terraform apply --var-file=dev.tfvars
```

---

## Summary

**Key Points:**
1. ✅ Ingress creates ALB automatically (via AWS Load Balancer Controller)
2. ✅ ALB is internal, not directly accessible from internet
3. ✅ CloudFront → API Gateway → VPC Link → ALB → Pods
4. ✅ Path-based routing works across all 7 services
5. ✅ Lambda authorizer ensures only CloudFront can access API Gateway
6. ✅ No DNS changes needed until you want custom domain

**The connection is made by updating API Gateway integration URI to point to ALB listener ARN - that's it!**
