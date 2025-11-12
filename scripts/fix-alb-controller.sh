#!/bin/bash
# Fix AWS Load Balancer Controller Issues

echo "======================================================"
echo "Fixing AWS Load Balancer Controller"
echo "======================================================"
echo ""

# Get IAM role ARN
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
OIDC_PROVIDER=$(aws eks describe-cluster --name malawi-pg-azampay-eks-cluster --region eu-central-1 --query "cluster.identity.oidc.issuer" --output text | sed -e "s/^https:\/\///")
ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/AmazonEKSLoadBalancerControllerRole"

echo "Account: $AWS_ACCOUNT_ID"
echo "OIDC Provider: $OIDC_PROVIDER"
echo "IAM Role ARN: $ROLE_ARN"
echo ""

# Step 1: Fix ServiceAccount - add IAM role annotation
echo "Step 1: Updating ServiceAccount with IAM role annotation..."
echo "-----------------------------------------------------------"

kubectl annotate serviceaccount aws-load-balancer-controller \
  -n kube-system \
  eks.amazonaws.com/role-arn=$ROLE_ARN \
  --overwrite

echo "✅ ServiceAccount updated"
echo ""

# Step 2: Create IngressClass
echo "Step 2: Creating IngressClass 'alb'..."
echo "---------------------------------------"

cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: IngressClass
metadata:
  name: alb
  annotations:
    ingressclass.kubernetes.io/is-default-class: "true"
spec:
  controller: ingress.k8s.aws/alb
EOF

echo "✅ IngressClass created"
echo ""

# Step 3: Restart controller to pick up changes
echo "Step 3: Restarting controller..."
echo "---------------------------------"

kubectl rollout restart deployment aws-load-balancer-controller -n kube-system

echo "Waiting for controller to be ready..."
sleep 10

kubectl rollout status deployment aws-load-balancer-controller -n kube-system --timeout=120s

echo "✅ Controller restarted"
echo ""

# Step 4: Verify controller is working
echo "Step 4: Verifying controller..."
echo "--------------------------------"

kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

echo ""
echo "Controller logs (last 20 lines):"
kubectl logs -n kube-system deployment/aws-load-balancer-controller --tail=20

echo ""
echo ""

# Step 5: Check if controller now reconciles Ingress
echo "Step 5: Checking Ingress status..."
echo "-----------------------------------"

sleep 5

kubectl get ingress --all-namespaces

echo ""
echo ""

# Step 6: Watch for ALB creation
echo "Step 6: Waiting for ALB creation (this may take 2-3 minutes)..."
echo "---------------------------------------------------------------"

echo "Watching Ingress for ADDRESS to populate..."
echo "(Press Ctrl+C after ADDRESS appears)"
echo ""

kubectl get ingress --all-namespaces -w &
WATCH_PID=$!

# Wait for 3 minutes or until user interrupts
sleep 180

kill $WATCH_PID 2>/dev/null

echo ""
echo ""
echo "======================================================"
echo "Verification"
echo "======================================================"
echo ""

# Check for ALB
echo "Checking for ALB in AWS..."
aws elbv2 describe-load-balancers \
  --query "LoadBalancers[?contains(LoadBalancerName, 'k8s-pgvnext')].{Name:LoadBalancerName,DNS:DNSName,State:State.Code}" \
  --output table

echo ""
echo ""
echo "If ALB is still not created after 3 minutes, check:"
echo "1. Controller logs: kubectl logs -n kube-system deployment/aws-load-balancer-controller"
echo "2. Ingress events: kubectl describe ingress -n ns-pgvnext-checkout-api prod-pgvnext-checkout-api-ingress"
echo "3. IAM role trust policy allows the OIDC provider"
