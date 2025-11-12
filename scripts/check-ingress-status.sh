#!/bin/bash
# Check Ingress and ALB Status
# Run this on bastion to verify ALB creation

echo "======================================================"
echo "Checking Ingress and ALB Status"
echo "======================================================"
echo ""

# Check Ingress resources
echo "1. Ingress Resources:"
echo "-------------------"
kubectl get ingress --all-namespaces

echo ""
echo ""

# Check controller logs
echo "2. AWS Load Balancer Controller Logs (last 30 lines):"
echo "----------------------------------------------------"
kubectl logs -n kube-system deployment/aws-load-balancer-controller --tail=30

echo ""
echo ""

# Check for ALB in AWS
echo "3. ALBs in AWS:"
echo "---------------"
aws elbv2 describe-load-balancers \
  --query "LoadBalancers[?contains(LoadBalancerName, 'k8s')].{Name:LoadBalancerName,DNS:DNSName,Scheme:Scheme,State:State.Code,VPC:VpcId}" \
  --output table

echo ""
echo ""

# If ALB exists, get details
ALB_ARN=$(aws elbv2 describe-load-balancers \
  --query "LoadBalancers[?contains(LoadBalancerName, 'k8s-pgvnext')].LoadBalancerArn" \
  --output text)

if [ ! -z "$ALB_ARN" ]; then
    echo "4. ALB Found! Getting details..."
    echo "-------------------------------"
    echo "ALB ARN: $ALB_ARN"
    echo ""
    
    # Get listener ARN
    LISTENER_ARN=$(aws elbv2 describe-listeners \
      --load-balancer-arn $ALB_ARN \
      --query "Listeners[?Port==\`80\`].ListenerArn" \
      --output text)
    
    echo "Listener ARN: $LISTENER_ARN"
    echo ""
    
    # Get target groups
    echo "5. Target Groups:"
    echo "----------------"
    aws elbv2 describe-target-groups \
      --load-balancer-arn $ALB_ARN \
      --query "TargetGroups[*].{Name:TargetGroupName,Port:Port,HealthPath:HealthCheckPath,Targets:TargetType}" \
      --output table
    
    echo ""
    echo ""
    
    # Check target health
    echo "6. Target Health Status:"
    echo "-----------------------"
    for TG_ARN in $(aws elbv2 describe-target-groups --load-balancer-arn $ALB_ARN --query "TargetGroups[*].TargetGroupArn" --output text); do
        TG_NAME=$(aws elbv2 describe-target-groups --target-group-arns $TG_ARN --query "TargetGroups[0].TargetGroupName" --output text)
        echo "Target Group: $TG_NAME"
        aws elbv2 describe-target-health --target-group-arn $TG_ARN --query "TargetHealthDescriptions[*].{Target:Target.Id,Port:Target.Port,Health:TargetHealth.State}" --output table
        echo ""
    done
    
    echo ""
    echo "======================================================"
    echo "Next Step: Update API Gateway Integration"
    echo "======================================================"
    echo ""
    echo "Save these values:"
    echo "ALB_ARN=$ALB_ARN"
    echo "LISTENER_ARN=$LISTENER_ARN"
    echo ""
    echo "Run these commands to update API Gateway:"
    echo ""
    echo "export ALB_ARN='$ALB_ARN'"
    echo "export LISTENER_ARN='$LISTENER_ARN'"
    echo ""
    echo "# Get API Gateway details"
    echo "API_ID=\$(aws apigatewayv2 get-apis --query \"Items[?Name=='pgvnext-http-api'].ApiId\" --output text)"
    echo "INTEGRATION_ID=\$(aws apigatewayv2 get-integrations --api-id \$API_ID --query \"Items[0].IntegrationId\" --output text)"
    echo ""
    echo "# Update integration to point to ALB"
    echo "aws apigatewayv2 update-integration --api-id \$API_ID --integration-id \$INTEGRATION_ID --integration-uri \$LISTENER_ARN"
    echo ""
    echo "# Deploy changes"
    echo "aws apigatewayv2 create-deployment --api-id \$API_ID --stage-name '\$default'"
    echo ""
else
    echo "❌ No ALB found with 'k8s-pgvnext' in the name"
    echo ""
    echo "Troubleshooting:"
    echo "---------------"
    echo "1. Check Ingress events:"
    echo "   kubectl describe ingress -n ns-pgvnext-checkout-api pgvnext-checkout-api-ingress"
    echo ""
    echo "2. Check controller is running:"
    echo "   kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller"
    echo ""
    echo "3. Check controller logs for errors:"
    echo "   kubectl logs -n kube-system deployment/aws-load-balancer-controller --tail=100"
fi
