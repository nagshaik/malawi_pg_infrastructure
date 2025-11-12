# Emergency script to manually update API Gateway integration to ALB
# This bypasses the issue with listener ARN format

$API_ID = "w9p0mqm2i3"
$OLD_INTEGRATION_ID = "ai4plg1"
$VPC_LINK_ID = "cofx2t"
$ALB_DNS = "internal-k8s-pgvnextsharedalb-6273fe7ae1-1648604953.eu-central-1.elb.amazonaws.com"

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Manually Updating API Gateway Integration to ALB" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

# Get all routes first
Write-Host "Getting current routes..." -ForegroundColor Green
$ROUTES = aws apigatewayv2 get-routes --api-id $API_ID --output json | ConvertFrom-Json

Write-Host "Found $($ROUTES.Items.Count) routes" -ForegroundColor Yellow
foreach ($route in $ROUTES.Items) {
    Write-Host "  - $($route.RouteKey) -> $($route.Target)" -ForegroundColor Gray
}
Write-Host ""

# Delete old integration
Write-Host "Deleting old integration..." -ForegroundColor Yellow
aws apigatewayv2 delete-integration --api-id $API_ID --integration-id $OLD_INTEGRATION_ID

Write-Host "Old integration deleted" -ForegroundColor Green
Write-Host ""

# Create new integration with ALB
Write-Host "Creating new integration with ALB..." -ForegroundColor Green
$NEW_INTEGRATION = aws apigatewayv2 create-integration `
    --api-id $API_ID `
    --integration-type HTTP_PROXY `
    --integration-method ANY `
    --integration-uri "http://$ALB_DNS" `
    --connection-type VPC_LINK `
    --connection-id $VPC_LINK_ID `
    --payload-format-version "1.0" `
    --request-parameters '{\"overwrite:path\":\"$request.path\"}' `
    --output json | ConvertFrom-Json

$NEW_INTEGRATION_ID = $NEW_INTEGRATION.IntegrationId
Write-Host "New integration created: $NEW_INTEGRATION_ID" -ForegroundColor Green
Write-Host ""

# Update routes to point to new integration
Write-Host "Updating routes to use new integration..." -ForegroundColor Green
foreach ($route in $ROUTES.Items) {
    $ROUTE_ID = $route.RouteId
    $ROUTE_KEY = $route.RouteKey
    
    Write-Host "  Updating route: $ROUTE_KEY" -ForegroundColor Yellow
    
    $UPDATE_CMD = "aws apigatewayv2 update-route --api-id $API_ID --route-id $ROUTE_ID --target integrations/$NEW_INTEGRATION_ID"
    
    # Preserve authorizer for $default route
    if ($ROUTE_KEY -eq '$default' -and $route.AuthorizerId) {
        $UPDATE_CMD += " --authorizer-id $($route.AuthorizerId) --authorization-type CUSTOM"
    }
    
    Invoke-Expression $UPDATE_CMD | Out-Null
    Write-Host "    ✓ Updated" -ForegroundColor Green
}

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "API Gateway Updated Successfully!" -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "New Integration ID: $NEW_INTEGRATION_ID" -ForegroundColor Yellow
Write-Host "Target: http://$ALB_DNS" -ForegroundColor Yellow
Write-Host ""
Write-Host "Testing in 5 seconds..." -ForegroundColor Gray
Start-Sleep -Seconds 5

Write-Host ""
Write-Host "Testing CloudFront endpoints:" -ForegroundColor Green
$PATHS = @("/checkout", "/c2b", "/admin", "/authenticator")
foreach ($PATH in $PATHS) {
    Write-Host "  Testing $PATH..." -ForegroundColor Cyan
    $RESULT = curl -s -o nul -w "%{http_code}" "https://d3d9sb62vwrxui.cloudfront.net$PATH" 2>$null
    if ($RESULT -eq "200") {
        Write-Host "    ✓ HTTP $RESULT" -ForegroundColor Green
    } else {
        Write-Host "    HTTP $RESULT" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Done! Architecture flow:" -ForegroundColor Cyan
Write-Host "  CloudFront -> API Gateway -> VPC Link -> ALB -> Pods" -ForegroundColor White
Write-Host "==================================================" -ForegroundColor Cyan
