# Deploy AWS Load Balancer Controller and Ingress Resources

## Step 1: Install AWS Load Balancer Controller (on Bastion)

The AWS Load Balancer Controller is what creates and manages the ALB based on Ingress resources.

### Upload the installation script to bastion:
```powershell
# From your local machine
scp c:\Users\nagin\malawi-pg-infra\scripts\install-alb-controller-manual.sh user@bastion-ip:/tmp/
scp c:\Users\nagin\malawi-pg-infra\k8s-manifests\pgvnext-ingress.yaml user@bastion-ip:/tmp/
```

### SSH to bastion and run:
```bash
ssh user@bastion-ip

cd /tmp
chmod +x install-alb-controller-manual.sh

# Run the installation script
./install-alb-controller-manual.sh
```

### Verify controller installation:
```bash
# Check deployment
kubectl get deployment -n kube-system aws-load-balancer-controller

# Expected output:
# NAME                           READY   UP-TO-DATE   AVAILABLE   AGE
# aws-load-balancer-controller   2/2     2            2           1m

# Check pods
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# Expected output:
# NAME                                            READY   STATUS    RESTARTS   AGE
# aws-load-balancer-controller-xxxxxxxxxx-xxxxx   1/1     Running   0          1m
# aws-load-balancer-controller-xxxxxxxxxx-xxxxx   1/1     Running   0          1m

# Check logs to ensure it's working
kubectl logs -n kube-system deployment/aws-load-balancer-controller --tail=20

# Should see logs like:
# {"level":"info","ts":"...","msg":"Reconciling ingress"}
```

---

## Step 2: Apply Ingress Resources

Now that the controller is installed, apply the Ingress resources. The controller will automatically create the ALB.

```bash
# Apply the Ingress manifests
kubectl apply -f /tmp/pgvnext-ingress.yaml

# Expected output:
# ingress.networking.k8s.io/pgvnext-checkout-api-ingress created
# ingress.networking.k8s.io/pgvnext-checkout-bg-ingress created
# ingress.networking.k8s.io/pgvnext-consumer-api-ingress created
# ingress.networking.k8s.io/pgvnext-core-api-ingress created
# ingress.networking.k8s.io/pgvnext-admin-panel-ingress created
# ingress.networking.k8s.io/pgvnext-admin-api-ingress created
# ingress.networking.k8s.io/pgvnext-authenticator-ingress created

# Watch controller create the ALB (may take 2-3 minutes)
kubectl get ingress --all-namespaces -w
```

### What happens during ALB creation:

1. **Controller detects Ingress resources** with `alb.ingress.kubernetes.io/group.name: pgvnext-shared-alb`
2. **Creates shared ALB** with name like `k8s-pgvnext-pgvnexts-abc123456`
3. **Configures ALB** with:
   - Internal scheme (not internet-facing)
   - Private subnets: subnet-0ee8553b798281422, subnet-01305039c8b7ea096
   - Target type: IP (routes directly to pod IPs)
4. **Creates 7 target groups** (one per service/path)
5. **Configures routing rules**:
   - `/checkout` → Checkout API target group
   - `/callback` → Callback service target group
   - `/consumer` → Consumer API target group
   - `/c2b` → Core API target group
   - `/admin` → Admin Portal target group
   - `/adminservice` → Admin Service target group
   - `/authenticator` → Authenticator target group
6. **Updates Ingress status** with ALB DNS name

### Monitor ALB creation:

```bash
# Watch Ingress resources (wait for ADDRESS to populate)
kubectl get ingress --all-namespaces

# Initially shows:
# NAMESPACE            NAME                          CLASS   HOSTS   ADDRESS   PORTS   AGE
# ns-pgvnext-checkout-api   pgvnext-checkout-api-ingress   <none>  *       <pending> 80      30s

# After ~2-3 minutes, ADDRESS appears:
# NAMESPACE            NAME                          CLASS   HOSTS   ADDRESS                                                   PORTS   AGE
# ns-pgvnext-checkout-api   pgvnext-checkout-api-ingress   <none>  *   k8s-pgvnext-pgvnexts-abc123-1234567890.eu-central-1.elb.amazonaws.com   80   3m

# Check controller logs to see ALB creation progress
kubectl logs -n kube-system deployment/aws-load-balancer-controller --tail=50 -f

# Look for log entries like:
# {"level":"info","msg":"creating LoadBalancer","stackID":"...","resourceID":"AWS::ElasticLoadBalancingV2::LoadBalancer"}
# {"level":"info","msg":"created LoadBalancer","LoadBalancerArn":"arn:aws:elasticloadbalancing:..."}
# {"level":"info","msg":"creating TargetGroup","stackID":"..."}
```

---

## Step 3: Verify ALB Created in AWS

```bash
# List ALBs
aws elbv2 describe-load-balancers \
  --query "LoadBalancers[?contains(LoadBalancerName, 'k8s-pgvnext')].{Name:LoadBalancerName,DNS:DNSName,Scheme:Scheme,State:State.Code}" \
  --output table

# Expected output:
# --------------------------------------------------------
# |              DescribeLoadBalancers                   |
# +-----------------+--------+-------------+------------+
# |      DNS        |  Name  |   Scheme    |   State    |
# +-----------------+--------+-------------+------------+
# | k8s-pgvnext-... | k8s... | internal    | active     |
# +-----------------+--------+-------------+------------+

# Get ALB ARN (save this!)
export ALB_ARN=$(aws elbv2 describe-load-balancers \
  --query "LoadBalancers[?contains(LoadBalancerName, 'k8s-pgvnext')].LoadBalancerArn" \
  --output text)

echo "ALB ARN: $ALB_ARN"

# List target groups
aws elbv2 describe-target-groups \
  --load-balancer-arn $ALB_ARN \
  --query "TargetGroups[*].{Name:TargetGroupName,Port:Port,Protocol:Protocol,HealthCheckPath:HealthCheckPath}" \
  --output table

# Expected: 7 target groups, one per service

# Check target health
for TG_ARN in $(aws elbv2 describe-target-groups --load-balancer-arn $ALB_ARN --query "TargetGroups[*].TargetGroupArn" --output text); do
  echo "Checking targets for: $TG_ARN"
  aws elbv2 describe-target-health --target-group-arn $TG_ARN
  echo ""
done

# Expected: Targets should show "State": "healthy" or "initial" (if still registering)
```

---

## Step 4: Get ALB Listener ARN for API Gateway Integration

```bash
# Get the HTTP listener ARN (port 80)
export LISTENER_ARN=$(aws elbv2 describe-listeners \
  --load-balancer-arn $ALB_ARN \
  --query "Listeners[?Port==\`80\`].ListenerArn" \
  --output text)

echo "Listener ARN: $LISTENER_ARN"
echo ""
echo "Save this ARN - you'll need it to update API Gateway integration"
```

---

## Step 5: Update API Gateway to Point to ALB

Now connect API Gateway to the ALB created by the Ingress Controller:

```bash
# From your local machine or bastion
cd /path/to/malawi-pg-infra/eks

# Get API Gateway ID
API_ID=$(terraform output -raw api_gateway_id)

# Get integration ID
INTEGRATION_ID=$(aws apigatewayv2 get-integrations \
  --api-id $API_ID \
  --query "Items[0].IntegrationId" \
  --output text)

echo "API Gateway ID: $API_ID"
echo "Integration ID: $INTEGRATION_ID"
echo "Target Listener ARN: $LISTENER_ARN"

# Update API Gateway integration to point to ALB
aws apigatewayv2 update-integration \
  --api-id $API_ID \
  --integration-id $INTEGRATION_ID \
  --integration-uri $LISTENER_ARN \
  --connection-type VPC_LINK

# Deploy the changes
aws apigatewayv2 create-deployment \
  --api-id $API_ID \
  --stage-name '$default'

echo ""
echo "✅ API Gateway now routes to ALB created by Ingress Controller"
```

---

## Step 6: Test End-to-End

```bash
# Test via CloudFront (public endpoint)
curl -v "https://d3d9sb62vwrxui.cloudfront.net/checkout"
curl -v "https://d3d9sb62vwrxui.cloudfront.net/c2b"
curl -v "https://d3d9sb62vwrxui.cloudfront.net/admin"

# Should return 200 OK or your application response (not 503!)
```

---

## Architecture Flow

```
┌──────────────┐
│   Internet   │
└──────┬───────┘
       │
       v
┌──────────────────────┐
│   CloudFront         │ (d3d9sb62vwrxui.cloudfront.net)
│   + WAF              │
└──────┬───────────────┘
       │ (x-origin-verify header)
       v
┌──────────────────────┐
│   API Gateway        │ (Private HTTP API)
│   + Lambda Authorizer│
└──────┬───────────────┘
       │
       v
┌──────────────────────┐
│   VPC Link           │ (alb_vpc_link)
└──────┬───────────────┘
       │
       v
┌──────────────────────────────────┐
│   ALB (Internal)                 │ ← Created by AWS Load Balancer Controller
│   k8s-pgvnext-shared-alb-*       │    from Ingress resources
│   ┌──────────────────────────┐   │
│   │ Routing Rules:           │   │
│   │ /checkout → TG1          │   │
│   │ /callback → TG2          │   │
│   │ /consumer → TG3          │   │
│   │ /c2b      → TG4          │   │
│   │ /admin    → TG5          │   │
│   │ /adminservice → TG6      │   │
│   │ /authenticator → TG7     │   │
│   └──────────────────────────┘   │
└────────────┬─────────────────────┘
             │ (Target Type: IP)
             v
    ┌────────────────────┐
    │   EKS Pods         │
    │   - Checkout       │
    │   - Callback       │
    │   - Consumer       │
    │   - Core API       │
    │   - Admin Portal   │
    │   - Admin Service  │
    │   - Authenticator  │
    └────────────────────┘
```

---

## Key Points

✅ **Ingress Controller creates the ALB** - it's not pre-existing
✅ **Ingress resources define ALB configuration** via annotations
✅ **All 7 Ingress resources share ONE ALB** via `group.name: pgvnext-shared-alb`
✅ **ALB is internal** - not directly accessible from internet
✅ **API Gateway connects to ALB** via VPC Link using listener ARN
✅ **Path-based routing** happens at the ALB level

---

## Troubleshooting

### Ingress stuck without ADDRESS
```bash
# Check controller is running
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# Check controller logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller --tail=100

# Check Ingress events
kubectl describe ingress -n ns-pgvnext-checkout-api pgvnext-checkout-api-ingress
```

### ALB created but targets unhealthy
```bash
# Check pods are running
kubectl get pods --all-namespaces | grep pgvnext

# Check service endpoints
kubectl get endpoints -n ns-pgvnext-checkout-api

# Check security groups allow ALB → Pod traffic
```

### 502/503 from CloudFront
```bash
# Verify API Gateway integration updated
aws apigatewayv2 get-integrations --api-id $API_ID

# Check VPC Link status
aws apigatewayv2 get-vpc-links

# Check ALB targets are healthy
aws elbv2 describe-target-health --target-group-arn <TG_ARN>
```
