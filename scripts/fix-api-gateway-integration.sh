#!/bin/bash

# Emergency script to manually update API Gateway integration to ALB
# This bypasses the issue with listener ARN format

set -e

API_ID="w9p0mqm2i3"
OLD_INTEGRATION_ID="ai4plg1"
VPC_LINK_ID="cofx2t"
ALB_DNS="internal-k8s-pgvnextsharedalb-6273fe7ae1-1648604953.eu-central-1.elb.amazonaws.com"
ALB_LISTENER_ARN="arn:aws:elasticloadbalancing:eu-central-1:550347237240:listener/app/k8s-pgvnextsharedalb-6273fe7ae1/1d8e5828b868acdb/68127a7d20fe2763"

echo "=================================================="
echo "Manually Updating API Gateway Integration to ALB"
echo "=================================================="
echo ""

# Get all routes first
echo "Getting current routes..."
ROUTES_JSON=$(aws apigatewayv2 get-routes --api-id $API_ID --output json)
echo "$ROUTES_JSON" | jq -r '.Items[] | "\(.RouteKey) -> \(.Target)"'
echo ""

# Save route details for later
echo "$ROUTES_JSON" > /tmp/routes_backup.json
echo "Routes backed up to /tmp/routes_backup.json"
echo ""

# Get route details BEFORE creating new integration
DEFAULT_ROUTE_ID=$(echo "$ROUTES_JSON" | jq -r '.Items[] | select(.RouteKey == "$default") | .RouteId')
DEFAULT_AUTH_ID=$(echo "$ROUTES_JSON" | jq -r '.Items[] | select(.RouteKey == "$default") | .AuthorizerId // empty')
HEALTH_ROUTE_ID=$(echo "$ROUTES_JSON" | jq -r '.Items[] | select(.RouteKey == "GET /health") | .RouteId')

# Create new integration with ALB FIRST (before deleting old one)
echo "Creating new integration with ALB..."
echo "Using ALB Listener ARN: $ALB_LISTENER_ARN"
NEW_INTEGRATION_JSON=$(aws apigatewayv2 create-integration \
    --api-id $API_ID \
    --integration-type HTTP_PROXY \
    --integration-method ANY \
    --integration-uri "$ALB_LISTENER_ARN" \
    --connection-type VPC_LINK \
    --connection-id $VPC_LINK_ID \
    --payload-format-version "1.0" \
    --request-parameters '{"overwrite:path":"$request.path"}' \
    --output json)

NEW_INTEGRATION_ID=$(echo "$NEW_INTEGRATION_JSON" | jq -r '.IntegrationId')
echo "New integration created: $NEW_INTEGRATION_ID"
echo ""

# Update routes to point to new integration
echo "Updating routes to use new integration..."

# Update $default route (with authorizer)
if [ -n "$DEFAULT_ROUTE_ID" ]; then
    echo "  Updating route: \$default"
    if [ -n "$DEFAULT_AUTH_ID" ]; then
        aws apigatewayv2 update-route \
            --api-id $API_ID \
            --route-id $DEFAULT_ROUTE_ID \
            --target "integrations/$NEW_INTEGRATION_ID" \
            --authorizer-id $DEFAULT_AUTH_ID \
            --authorization-type CUSTOM > /dev/null
    else
        aws apigatewayv2 update-route \
            --api-id $API_ID \
            --route-id $DEFAULT_ROUTE_ID \
            --target "integrations/$NEW_INTEGRATION_ID" > /dev/null
    fi
    echo "    ✓ Updated"
fi

# Update health check route (no authorizer)
if [ -n "$HEALTH_ROUTE_ID" ]; then
    echo "  Updating route: GET /health"
    aws apigatewayv2 update-route \
        --api-id $API_ID \
        --route-id $HEALTH_ROUTE_ID \
        --target "integrations/$NEW_INTEGRATION_ID" > /dev/null
    echo "    ✓ Updated"
fi

# Now delete old integration (after routes are updated)
echo ""
echo "Deleting old NLB integration..."
aws apigatewayv2 delete-integration --api-id $API_ID --integration-id $OLD_INTEGRATION_ID
echo "Old integration deleted"

echo ""
echo "=================================================="
echo "API Gateway Updated Successfully!"
echo "=================================================="
echo ""
echo "New Integration ID: $NEW_INTEGRATION_ID"
echo "Target ALB: $ALB_DNS"
echo "Listener ARN: $ALB_LISTENER_ARN"
echo ""
echo "Testing in 5 seconds..."
sleep 5

echo ""
echo "Testing CloudFront endpoints:"
for PATH in /checkout /c2b /admin /authenticator; do
    echo "  Testing $PATH..."
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "https://d3d9sb62vwrxui.cloudfront.net$PATH" 2>&1 || echo "000")
    if [ "$HTTP_CODE" = "200" ]; then
        echo "    ✓ HTTP $HTTP_CODE"
    else
        echo "    HTTP $HTTP_CODE"
    fi
done

echo ""
echo "=================================================="
echo "Done! Architecture flow:"
echo "  CloudFront -> API Gateway -> VPC Link -> ALB -> Pods"
echo "=================================================="
