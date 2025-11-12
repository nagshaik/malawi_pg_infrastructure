# Script to update API Gateway integration to point to the ALB created by Ingress Controller
# This connects CloudFront -> API Gateway -> ALB -> EKS Pods

$ALB_LISTENER_ARN = "arn:aws:elasticloadbalancing:eu-central-1:550347237240:listener/app/k8s-pgvnextsharedalb-6273fe7ae1/1d8e5828b868acdb/68127a7d20fe2763"
$ALB_ARN = "arn:aws:elasticloadbalancing:eu-central-1:550347237240:loadbalancer/app/k8s-pgvnextsharedalb-6273fe7ae1/1d8e5828b868acdb"
$ALB_DNS = "internal-k8s-pgvnextsharedalb-6273fe7ae1-1648604953.eu-central-1.elb.amazonaws.com"

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Updating API Gateway to point to ALB" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "ALB DNS: $ALB_DNS" -ForegroundColor Yellow
Write-Host "ALB ARN: $ALB_ARN" -ForegroundColor Yellow
Write-Host "Listener ARN: $ALB_LISTENER_ARN" -ForegroundColor Yellow
Write-Host ""

# Navigate to Terraform directory
Set-Location "c:\Users\nagin\malawi-pg-infra\eks"

# Get API Gateway ID from Terraform output
Write-Host "Getting API Gateway ID from Terraform..." -ForegroundColor Green
$API_ID = terraform output -raw api_gateway_id 2>$null

if ([string]::IsNullOrEmpty($API_ID)) {
    Write-Host "ERROR: Could not get API Gateway ID from Terraform output" -ForegroundColor Red
    Write-Host "Make sure to run 'terraform apply' first to create the API Gateway" -ForegroundColor Yellow
    exit 1
}

Write-Host "API Gateway ID: $API_ID" -ForegroundColor Green
Write-Host ""

# Get current integration ID
Write-Host "Getting current integration..." -ForegroundColor Green
$INTEGRATION_ID = aws apigatewayv2 get-integrations --api-id $API_ID --query "Items[0].IntegrationId" --output text

if ([string]::IsNullOrEmpty($INTEGRATION_ID) -or $INTEGRATION_ID -eq "None") {
    Write-Host "No integration found. Creating new VPC Link integration..." -ForegroundColor Yellow
    
    # Get VPC Link ID
    $VPC_LINK_ID = terraform output -raw vpc_link_id 2>$null
    
    if ([string]::IsNullOrEmpty($VPC_LINK_ID)) {
        Write-Host "ERROR: Could not get VPC Link ID" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "VPC Link ID: $VPC_LINK_ID" -ForegroundColor Yellow
    
    # Create integration
    $INTEGRATION = aws apigatewayv2 create-integration `
        --api-id $API_ID `
        --integration-type HTTP_PROXY `
        --integration-uri $ALB_LISTENER_ARN `
        --integration-method ANY `
        --connection-type VPC_LINK `
        --connection-id $VPC_LINK_ID `
        --payload-format-version 1.0 | ConvertFrom-Json
    
    $INTEGRATION_ID = $INTEGRATION.IntegrationId
    Write-Host "Created integration: $INTEGRATION_ID" -ForegroundColor Green
} else {
    Write-Host "Found existing integration: $INTEGRATION_ID" -ForegroundColor Green
    Write-Host "Updating integration URI to point to ALB..." -ForegroundColor Yellow
    
    # Update existing integration
    aws apigatewayv2 update-integration `
        --api-id $API_ID `
        --integration-id $INTEGRATION_ID `
        --integration-uri $ALB_LISTENER_ARN | Out-Null
    
    Write-Host "Integration updated successfully!" -ForegroundColor Green
}

Write-Host ""
Write-Host "Deploying API Gateway changes..." -ForegroundColor Green
aws apigatewayv2 create-deployment --api-id $API_ID --stage-name '$default' | Out-Null

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "API Gateway Integration Complete!" -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Architecture Flow:" -ForegroundColor Yellow
Write-Host "  Internet -> CloudFront (d3d9sb62vwrxui.cloudfront.net)" -ForegroundColor White
Write-Host "  CloudFront -> API Gateway ($API_ID)" -ForegroundColor White
Write-Host "  API Gateway -> VPC Link -> ALB ($ALB_DNS)" -ForegroundColor White
Write-Host "  ALB -> EKS Pods (7 services)" -ForegroundColor White
Write-Host ""
Write-Host "Test the integration:" -ForegroundColor Yellow
Write-Host "  curl https://d3d9sb62vwrxui.cloudfront.net/checkout" -ForegroundColor Cyan
Write-Host "  curl https://d3d9sb62vwrxui.cloudfront.net/c2b" -ForegroundColor Cyan
Write-Host "  curl https://d3d9sb62vwrxui.cloudfront.net/admin" -ForegroundColor Cyan
Write-Host ""
Write-Host "Check target health:" -ForegroundColor Yellow
Write-Host "  aws elbv2 describe-target-health --target-group-arn <tg-arn>" -ForegroundColor Cyan
Write-Host ""
