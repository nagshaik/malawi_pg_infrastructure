#!/bin/bash
# Troubleshoot Ingress - Why ALB is not being created

echo "======================================================"
echo "Troubleshooting Ingress - ALB Not Created"
echo "======================================================"
echo ""

# 1. Check if AWS Load Balancer Controller is running
echo "1. Checking AWS Load Balancer Controller status..."
echo "---------------------------------------------------"
kubectl get deployment -n kube-system aws-load-balancer-controller
echo ""
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
echo ""

# 2. Check controller logs for errors
echo "2. Controller logs (last 50 lines)..."
echo "--------------------------------------"
kubectl logs -n kube-system deployment/aws-load-balancer-controller --tail=50
echo ""
echo ""

# 3. Check Ingress events for errors
echo "3. Checking Ingress events..."
echo "-----------------------------"
for NS in ns-pgvnext-checkout-api ns-pgvnext-checkout-background-service ns-pgvnext-consumer-api ns-pgvnext-core-api prod-pgvnext-admin-panel-app-namespace prod-pgvnext-admin-panel-service-app-namespace prod-pgvnext-authenticator-app-namespace; do
    echo "Namespace: $NS"
    INGRESS_NAME=$(kubectl get ingress -n $NS -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ ! -z "$INGRESS_NAME" ]; then
        echo "Ingress: $INGRESS_NAME"
        kubectl describe ingress -n $NS $INGRESS_NAME | grep -A 20 "Events:"
    fi
    echo ""
done

echo ""
echo ""

# 4. Check if IngressClass exists
echo "4. Checking IngressClass..."
echo "---------------------------"
kubectl get ingressclass
echo ""

# 5. Check ServiceAccount has IAM role
echo "5. Checking ServiceAccount IAM annotation..."
echo "--------------------------------------------"
kubectl get serviceaccount aws-load-balancer-controller -n kube-system -o yaml | grep -A 5 annotations
echo ""

# 6. Check if pods can assume IAM role
echo "6. Checking controller pod IAM credentials..."
echo "---------------------------------------------"
POD_NAME=$(kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller -o jsonpath='{.items[0].metadata.name}')
if [ ! -z "$POD_NAME" ]; then
    echo "Testing IAM credentials in pod: $POD_NAME"
    kubectl exec -n kube-system $POD_NAME -- env | grep AWS
    echo ""
    kubectl exec -n kube-system $POD_NAME -- aws sts get-caller-identity 2>&1 || echo "Failed to get IAM identity"
fi

echo ""
echo "======================================================"
echo "Common Issues & Solutions"
echo "======================================================"
echo ""
echo "Issue 1: Controller not running"
echo "  Solution: Restart controller deployment"
echo "  kubectl rollout restart deployment aws-load-balancer-controller -n kube-system"
echo ""
echo "Issue 2: Missing IngressClass"
echo "  Solution: The controller should create it automatically"
echo "  Check: kubectl get ingressclass"
echo ""
echo "Issue 3: IAM permissions"
echo "  Solution: Verify ServiceAccount has correct IAM role annotation"
echo "  Check: kubectl get sa aws-load-balancer-controller -n kube-system -o yaml"
echo ""
echo "Issue 4: Ingress annotations"
echo "  Solution: Ensure Ingress uses correct class"
echo "  Check: kubernetes.io/ingress.class: alb"
echo ""
