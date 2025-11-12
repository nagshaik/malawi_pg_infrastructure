#!/bin/bash
# Script to test CloudFront → API Gateway → ALB → EKS Services routing

echo "======================================================"
echo "CloudFront Routing Test Script"
echo "======================================================"
echo ""

# Get the CloudFront domain from Terraform
echo "Step 1: Getting CloudFront domain..."
cd /c/Users/nagin/malawi-pg-infra/eks
CLOUDFRONT_DOMAIN=$(terraform output -raw cloudfront_distribution_domain 2>/dev/null)

if [ -z "$CLOUDFRONT_DOMAIN" ]; then
    echo "❌ Error: CloudFront domain not found. Run 'terraform apply' first."
    exit 1
fi

echo "✅ CloudFront Domain: $CLOUDFRONT_DOMAIN"
echo ""

# Get API Gateway endpoint
API_GATEWAY_ENDPOINT=$(terraform output -raw api_gateway_endpoint 2>/dev/null)
echo "📍 API Gateway Endpoint: $API_GATEWAY_ENDPOINT"
echo ""

# Test services through CloudFront
echo "======================================================"
echo "Testing Services via CloudFront (Should Work ✅)"
echo "======================================================"
echo ""

declare -a services=(
    "/checkout:Checkout API"
    "/checkout-bg:Checkout Background"
    "/consumer:Consumer API"
    "/core:Core API"
    "/admin:Admin Panel"
    "/admin-api:Admin Panel API"
    "/auth:Authenticator"
)

for service in "${services[@]}"; do
    IFS=':' read -r path name <<< "$service"
    echo "Testing: $name ($path)"
    
    response=$(curl -s -w "\n%{http_code}" -X GET "https://${CLOUDFRONT_DOMAIN}${path}/health" \
        -H "Accept: application/json" \
        -H "User-Agent: CloudFront-Test" \
        --max-time 10)
    
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n-1)
    
    if [ "$http_code" = "200" ] || [ "$http_code" = "201" ] || [ "$http_code" = "204" ]; then
        echo "  ✅ Status: $http_code - Success"
    elif [ "$http_code" = "404" ]; then
        echo "  ⚠️  Status: $http_code - Service endpoint not found (check path)"
    elif [ "$http_code" = "502" ] || [ "$http_code" = "503" ]; then
        echo "  ❌ Status: $http_code - Backend unavailable"
    else
        echo "  ❌ Status: $http_code"
    fi
    
    # Show response headers
    headers=$(curl -s -I -X GET "https://${CLOUDFRONT_DOMAIN}${path}/health" --max-time 10)
    echo "  Response Headers:"
    echo "$headers" | grep -i "x-cache\|x-amz\|server" | sed 's/^/    /'
    echo ""
done

echo ""
echo "======================================================"
echo "Testing Direct API Gateway Access (Should Fail ❌)"
echo "======================================================"
echo ""

# Strip https:// from API Gateway endpoint
API_GATEWAY_HOST=$(echo "$API_GATEWAY_ENDPOINT" | sed 's|https://||' | sed 's|/$||')

echo "Testing: Direct API Gateway - /checkout/health"
response=$(curl -s -w "\n%{http_code}" -X GET "https://${API_GATEWAY_HOST}/checkout/health" \
    -H "Accept: application/json" \
    --max-time 10)

http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | head -n-1)

if [ "$http_code" = "403" ]; then
    echo "  ✅ Status: $http_code - Correctly blocked (no CloudFront header)"
    echo "  Response: $body"
else
    echo "  ⚠️  Status: $http_code - API Gateway should return 403"
    echo "  Response: $body"
fi

echo ""
echo "======================================================"
echo "ALB and Target Health Check"
echo "======================================================"
echo ""

# Get ALB ARN
ALB_ARN=$(aws elbv2 describe-load-balancers \
    --query "LoadBalancers[?contains(LoadBalancerName, 'pgvnext')].LoadBalancerArn" \
    --output text 2>/dev/null)

if [ -n "$ALB_ARN" ]; then
    echo "ALB ARN: $ALB_ARN"
    
    # Get target groups
    echo ""
    echo "Target Groups and Health:"
    aws elbv2 describe-target-groups \
        --load-balancer-arn "$ALB_ARN" \
        --query "TargetGroups[*].[TargetGroupName,Port,HealthCheckPath,HealthCheckProtocol]" \
        --output table
    
    # Get target health
    TG_ARNS=$(aws elbv2 describe-target-groups \
        --load-balancer-arn "$ALB_ARN" \
        --query "TargetGroups[*].TargetGroupArn" \
        --output text)
    
    echo ""
    echo "Target Health Status:"
    for tg_arn in $TG_ARNS; do
        tg_name=$(aws elbv2 describe-target-groups \
            --target-group-arns "$tg_arn" \
            --query "TargetGroups[0].TargetGroupName" \
            --output text)
        
        echo ""
        echo "  Target Group: $tg_name"
        aws elbv2 describe-target-health \
            --target-group-arn "$tg_arn" \
            --query "TargetHealthDescriptions[*].[Target.Id,Target.Port,TargetHealth.State,TargetHealth.Reason]" \
            --output table | sed 's/^/    /'
    done
else
    echo "⚠️  No ALB found with 'pgvnext' in name"
    echo "Run: kubectl get ingress --all-namespaces"
fi

echo ""
echo "======================================================"
echo "CloudWatch Logs Check"
echo "======================================================"
echo ""

echo "Recent CloudFront logs (last 5 minutes):"
aws logs tail /aws/cloudfront/malawi-pg-api-distribution --since 5m --format short | head -20

echo ""
echo "Recent API Gateway logs (last 5 minutes):"
aws logs tail /aws/apigateway/malawi-pg-eks-http-api --since 5m --format short | head -20

echo ""
echo "======================================================"
echo "Summary"
echo "======================================================"
echo ""
echo "✅ Test CloudFront endpoints: https://${CLOUDFRONT_DOMAIN}/[path]"
echo "❌ Direct API Gateway should be blocked"
echo "📊 Check ALB target health for backend connectivity"
echo ""
echo "To verify end-to-end:"
echo "  curl -v https://${CLOUDFRONT_DOMAIN}/checkout/health"
echo "  curl -v https://${CLOUDFRONT_DOMAIN}/core/health"
echo ""
