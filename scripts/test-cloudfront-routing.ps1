# CloudFront Routing Test Script
# Tests the full routing chain: CloudFront → API Gateway → ALB → EKS Services

Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "CloudFront Routing Test Script" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host ""

# Get the CloudFront domain from Terraform
Write-Host "Step 1: Getting CloudFront domain..." -ForegroundColor Yellow
Set-Location "c:\Users\nagin\malawi-pg-infra\eks"

try {
    $CloudFrontDomain = terraform output -raw cloudfront_distribution_domain 2>$null
    if ([string]::IsNullOrEmpty($CloudFrontDomain)) {
        Write-Host "❌ Error: CloudFront domain not found. Run 'terraform apply' first." -ForegroundColor Red
        exit 1
    }
    Write-Host "✅ CloudFront Domain: $CloudFrontDomain" -ForegroundColor Green
} catch {
    Write-Host "❌ Error getting CloudFront domain: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Get API Gateway endpoint
try {
    $ApiGatewayEndpoint = terraform output -raw api_gateway_endpoint 2>$null
    Write-Host "📍 API Gateway Endpoint: $ApiGatewayEndpoint" -ForegroundColor Cyan
} catch {
    Write-Host "⚠️  Warning: Could not get API Gateway endpoint" -ForegroundColor Yellow
}

Write-Host ""

# Test services through CloudFront
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "Testing Services via CloudFront (Should Work ✅)" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host ""

$services = @(
    @{Path="/checkout"; Name="Checkout API"},
    @{Path="/checkout-bg"; Name="Checkout Background"},
    @{Path="/consumer"; Name="Consumer API"},
    @{Path="/core"; Name="Core API"},
    @{Path="/admin"; Name="Admin Panel"},
    @{Path="/admin-api"; Name="Admin Panel API"},
    @{Path="/auth"; Name="Authenticator"}
)

foreach ($service in $services) {
    Write-Host "Testing: $($service.Name) ($($service.Path))" -ForegroundColor White
    
    try {
        $url = "https://$CloudFrontDomain$($service.Path)/health"
        $response = Invoke-WebRequest -Uri $url -Method GET -Headers @{
            "Accept" = "application/json"
            "User-Agent" = "CloudFront-Test"
        } -TimeoutSec 10 -UseBasicParsing
        
        $statusCode = $response.StatusCode
        
        if ($statusCode -in 200, 201, 204) {
            Write-Host "  ✅ Status: $statusCode - Success" -ForegroundColor Green
        } else {
            Write-Host "  ⚠️  Status: $statusCode" -ForegroundColor Yellow
        }
        
        # Show CloudFront headers
        $cacheHeader = $response.Headers['X-Cache']
        $amzHeader = $response.Headers['X-Amz-Cf-Id']
        if ($cacheHeader) {
            Write-Host "  X-Cache: $cacheHeader" -ForegroundColor Gray
        }
        if ($amzHeader) {
            Write-Host "  X-Amz-Cf-Id: $amzHeader" -ForegroundColor Gray
        }
        
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        if ($statusCode -eq 404) {
            Write-Host "  ⚠️  Status: 404 - Service endpoint not found (check path)" -ForegroundColor Yellow
        } elseif ($statusCode -in 502, 503) {
            Write-Host "  ❌ Status: $statusCode - Backend unavailable" -ForegroundColor Red
        } else {
            Write-Host "  ❌ Status: $statusCode - Error: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    Write-Host ""
}

Write-Host ""
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "Testing Direct API Gateway Access (Should Fail ❌)" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host ""

if (![string]::IsNullOrEmpty($ApiGatewayEndpoint)) {
    $ApiGatewayHost = $ApiGatewayEndpoint -replace 'https://', '' -replace '/$', ''
    
    Write-Host "Testing: Direct API Gateway - /checkout/health" -ForegroundColor White
    
    try {
        $url = "https://$ApiGatewayHost/checkout/health"
        $response = Invoke-WebRequest -Uri $url -Method GET -Headers @{
            "Accept" = "application/json"
        } -TimeoutSec 10 -UseBasicParsing
        
        Write-Host "  ⚠️  Status: $($response.StatusCode) - API Gateway should return 403" -ForegroundColor Yellow
        
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        if ($statusCode -eq 403) {
            Write-Host "  ✅ Status: 403 - Correctly blocked (no CloudFront header)" -ForegroundColor Green
        } else {
            Write-Host "  ❌ Status: $statusCode - Unexpected response" -ForegroundColor Red
        }
    }
}

Write-Host ""
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "Ingress and ALB Status" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Checking Ingress resources..." -ForegroundColor Yellow
kubectl get ingress --all-namespaces

Write-Host ""
Write-Host "Checking ALB Load Balancers..." -ForegroundColor Yellow
aws elbv2 describe-load-balancers --query "LoadBalancers[?contains(LoadBalancerName, 'k8s')].{Name:LoadBalancerName,DNS:DNSName,State:State.Code,Scheme:Scheme}" --output table

Write-Host ""
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "CloudWatch Logs (Last 5 minutes)" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "CloudFront Logs:" -ForegroundColor Yellow
try {
    aws logs tail /aws/cloudfront/malawi-pg-api-distribution --since 5m --format short 2>$null | Select-Object -First 10
} catch {
    Write-Host "  No CloudFront logs found" -ForegroundColor Gray
}

Write-Host ""
Write-Host "API Gateway Logs:" -ForegroundColor Yellow
try {
    aws logs tail /aws/apigateway/malawi-pg-eks-http-api --since 5m --format short 2>$null | Select-Object -First 10
} catch {
    Write-Host "  No API Gateway logs found" -ForegroundColor Gray
}

Write-Host ""
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "Summary" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "✅ Test CloudFront endpoints: https://$CloudFrontDomain/[path]" -ForegroundColor Green
Write-Host "❌ Direct API Gateway should be blocked" -ForegroundColor Red
Write-Host "📊 Check Ingress and ALB status above" -ForegroundColor Cyan
Write-Host ""
Write-Host "Manual verification commands:" -ForegroundColor Yellow
Write-Host "  curl -v https://$CloudFrontDomain/checkout/health" -ForegroundColor White
Write-Host "  curl -v https://$CloudFrontDomain/core/health" -ForegroundColor White
Write-Host ""
Write-Host "Check ALB targets:" -ForegroundColor Yellow
Write-Host "  kubectl get pods --all-namespaces | Select-String 'pgvnext'" -ForegroundColor White
Write-Host "  kubectl describe ingress -n ns-pgvnext-checkout-api" -ForegroundColor White
Write-Host ""
