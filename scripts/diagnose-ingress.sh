#!/bin/bash
# Script to diagnose and fix Ingress creation issues

echo "======================================================"
echo "Diagnosing Ingress Creation Issues"
echo "======================================================"
echo ""

# Check if AWS Load Balancer Controller is installed
echo "Step 1: Checking AWS Load Balancer Controller..."
echo ""

LBC_DEPLOYED=$(kubectl get deployment -n kube-system aws-load-balancer-controller 2>/dev/null)
if [ -z "$LBC_DEPLOYED" ]; then
    echo "❌ AWS Load Balancer Controller is NOT installed"
    echo ""
    echo "This is why your Ingress resources are stuck in 'creating' state."
    echo ""
    echo "SOLUTION: Install AWS Load Balancer Controller"
    echo ""
else
    echo "✅ AWS Load Balancer Controller is installed"
    echo ""
    
    # Check controller status
    echo "Controller status:"
    kubectl get deployment -n kube-system aws-load-balancer-controller
    echo ""
    
    # Check controller logs
    echo "Recent controller logs:"
    kubectl logs -n kube-system deployment/aws-load-balancer-controller --tail=20
    echo ""
fi

# Check Ingress status
echo ""
echo "======================================================"
echo "Step 2: Checking Ingress Resources"
echo "======================================================"
echo ""

kubectl get ingress --all-namespaces

echo ""
echo "Detailed Ingress status (checking for errors):"
echo ""

for ns in ns-pgvnext-checkout-api ns-pgvnext-checkout-background-service ns-pgvnext-consumer-api ns-pgvnext-core-api prod-pgvnext-admin-panel-app-namespace prod-pgvnext-admin-panel-service-app-namespace prod-pgvnext-authenticator-app-namespace; do
    ingress=$(kubectl get ingress -n $ns -o name 2>/dev/null | head -1)
    if [ -n "$ingress" ]; then
        echo "Namespace: $ns"
        kubectl describe $ingress -n $ns | grep -A 5 "Events:"
        echo ""
    fi
done

# Check IAM role for service account
echo ""
echo "======================================================"
echo "Step 3: Checking IAM Permissions (IRSA)"
echo "======================================================"
echo ""

SA_EXISTS=$(kubectl get sa -n kube-system aws-load-balancer-controller 2>/dev/null)
if [ -z "$SA_EXISTS" ]; then
    echo "❌ ServiceAccount aws-load-balancer-controller not found"
else
    echo "✅ ServiceAccount exists"
    kubectl describe sa -n kube-system aws-load-balancer-controller | grep -i "annotations"
fi

echo ""
echo "======================================================"
echo "Summary & Next Steps"
echo "======================================================"
echo ""

if [ -z "$LBC_DEPLOYED" ]; then
    echo "PROBLEM: AWS Load Balancer Controller is missing"
    echo ""
    echo "SOLUTION:"
    echo "1. Install AWS Load Balancer Controller using Helm or kubectl"
    echo "2. See: install-alb-controller.sh script"
    echo ""
else
    echo "AWS Load Balancer Controller is installed."
    echo "Check the events and logs above for specific errors."
    echo ""
    echo "Common issues:"
    echo "- IAM permissions missing (IRSA not configured)"
    echo "- Subnet tags missing (kubernetes.io/role/internal-elb)"
    echo "- Security group issues"
    echo "- Controller version compatibility"
fi

echo ""
