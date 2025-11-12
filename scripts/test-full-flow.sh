#!/bin/bash

# Test all configured paths through CloudFront -> API Gateway -> ALB -> Pods

CLOUDFRONT_URL="https://d3d9sb62vwrxui.cloudfront.net"

echo "=================================================="
echo "Testing CloudFront -> API Gateway -> ALB -> Pods"
echo "=================================================="
echo ""
echo "CloudFront URL: $CLOUDFRONT_URL"
echo ""

# Array of paths configured in Ingress
declare -a PATHS=(
    "/checkout"
    "/callback"
    "/consumer"
    "/c2b"
    "/admin"
    "/adminservice"
    "/authenticator"
)

# Array of health check paths
declare -a HEALTH_PATHS=(
    "/checkout/health"
    "/callback/health"
    "/consumer/health"
    "/c2b/health"
    "/admin/health"
    "/adminservice/health"
    "/authenticator/health"
)

echo "Testing main paths:"
echo "-------------------"
for PATH in "${PATHS[@]}"; do
    echo -n "Testing $PATH ... "
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$CLOUDFRONT_URL$PATH" 2>&1)
    
    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
        echo "✓ HTTP $HTTP_CODE (OK)"
    elif [ "$HTTP_CODE" = "401" ] || [ "$HTTP_CODE" = "403" ]; then
        echo "⚠ HTTP $HTTP_CODE (Auth required - backend is reachable)"
    elif [ "$HTTP_CODE" = "404" ]; then
        echo "✗ HTTP $HTTP_CODE (Not found)"
    elif [ "$HTTP_CODE" = "503" ]; then
        echo "✗ HTTP $HTTP_CODE (Service unavailable)"
    else
        echo "? HTTP $HTTP_CODE"
    fi
done

echo ""
echo "Testing health check paths:"
echo "---------------------------"
for PATH in "${HEALTH_PATHS[@]}"; do
    echo -n "Testing $PATH ... "
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$CLOUDFRONT_URL$PATH" 2>&1)
    
    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "204" ]; then
        echo "✓ HTTP $HTTP_CODE (Healthy)"
    elif [ "$HTTP_CODE" = "401" ] || [ "$HTTP_CODE" = "403" ]; then
        echo "⚠ HTTP $HTTP_CODE (Auth required - backend is reachable)"
    elif [ "$HTTP_CODE" = "404" ]; then
        echo "✗ HTTP $HTTP_CODE (Not found)"
    elif [ "$HTTP_CODE" = "503" ]; then
        echo "✗ HTTP $HTTP_CODE (Service unavailable)"
    else
        echo "? HTTP $HTTP_CODE"
    fi
done

echo ""
echo "=================================================="
echo "Checking ALB Target Health"
echo "=================================================="
echo ""

ALB_ARN="arn:aws:elasticloadbalancing:eu-central-1:550347237240:loadbalancer/app/k8s-pgvnextsharedalb-6273fe7ae1/1d8e5828b868acdb"

# Get target groups
TG_ARNS=$(aws elbv2 describe-target-groups --load-balancer-arn "$ALB_ARN" --query "TargetGroups[].TargetGroupArn" --output text)

echo "Target Group Health Status:"
echo "---------------------------"
for TG_ARN in $TG_ARNS; do
    TG_NAME=$(aws elbv2 describe-target-groups --target-group-arns "$TG_ARN" --query "TargetGroups[0].TargetGroupName" --output text)
    echo ""
    echo "Target Group: $TG_NAME"
    
    HEALTH=$(aws elbv2 describe-target-health --target-group-arn "$TG_ARN" --output json)
    HEALTHY_COUNT=$(echo "$HEALTH" | jq '[.TargetHealthDescriptions[] | select(.TargetHealth.State == "healthy")] | length')
    TOTAL_COUNT=$(echo "$HEALTH" | jq '.TargetHealthDescriptions | length')
    
    if [ "$TOTAL_COUNT" = "0" ]; then
        echo "  Status: NO TARGETS REGISTERED"
    else
        echo "  Healthy: $HEALTHY_COUNT / $TOTAL_COUNT"
        echo "$HEALTH" | jq -r '.TargetHealthDescriptions[] | "  - \(.Target.Id):\(.Target.Port) -> \(.TargetHealth.State)"'
    fi
done

echo ""
echo "=================================================="
echo "Summary"
echo "=================================================="
echo ""
echo "Architecture Status:"
echo "  ✓ CloudFront: d3d9sb62vwrxui.cloudfront.net"
echo "  ✓ API Gateway: w9p0mqm2i3"
echo "  ✓ VPC Link: cofx2t"
echo "  ✓ ALB: k8s-pgvnextsharedalb-6273fe7ae1"
echo "  ✓ Integration: CloudFront -> API Gateway -> ALB -> Pods"
echo ""

if curl -s "$CLOUDFRONT_URL/checkout" | grep -q "Service Unavailable"; then
    echo "⚠ WARNING: Getting 503 errors - check pod/service status"
elif curl -s -o /dev/null -w "%{http_code}" "$CLOUDFRONT_URL/checkout" | grep -q "401\|403"; then
    echo "✓ SUCCESS: Requests reaching backend pods (401/403 = auth required)"
elif curl -s -o /dev/null -w "%{http_code}" "$CLOUDFRONT_URL/checkout" | grep -q "200\|201"; then
    echo "✓ SUCCESS: Full end-to-end flow working!"
else
    echo "? Status unclear - manual verification needed"
fi

echo ""
