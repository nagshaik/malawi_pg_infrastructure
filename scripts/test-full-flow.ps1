# Test all configured paths through CloudFront -> API Gateway -> ALB -> Pods

$CLOUDFRONT_URL = "https://d3d9sb62vwrxui.cloudfront.net"

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Testing CloudFront -> API Gateway -> ALB -> Pods" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "CloudFront URL: $CLOUDFRONT_URL" -ForegroundColor Yellow
Write-Host ""

# Array of paths configured in Ingress
$PATHS = @(
    "/checkout",
    "/callback",
    "/consumer",
    "/c2b",
    "/admin",
    "/adminservice",
    "/authenticator"
)

# Array of health check paths
$HEALTH_PATHS = @(
    "/checkout/health",
    "/callback/health",
    "/consumer/health",
    "/c2b/health",
    "/admin/health",
    "/adminservice/health",
    "/authenticator/health"
)

Write-Host "Testing main paths:" -ForegroundColor Green
Write-Host "-------------------" -ForegroundColor Green
foreach ($PATH in $PATHS) {
    Write-Host -NoNewline "Testing $PATH ... " -ForegroundColor Cyan
    try {
        $response = Invoke-WebRequest -Uri "$CLOUDFRONT_URL$PATH" -Method GET -TimeoutSec 10 -ErrorAction SilentlyContinue -SkipHttpErrorCheck
        $HTTP_CODE = $response.StatusCode
        
        if ($HTTP_CODE -eq 200 -or $HTTP_CODE -eq 201) {
            Write-Host "✓ HTTP $HTTP_CODE (OK)" -ForegroundColor Green
        } elseif ($HTTP_CODE -eq 401 -or $HTTP_CODE -eq 403) {
            Write-Host "⚠ HTTP $HTTP_CODE (Auth required - backend is reachable)" -ForegroundColor Yellow
        } elseif ($HTTP_CODE -eq 404) {
            Write-Host "✗ HTTP $HTTP_CODE (Not found)" -ForegroundColor Red
        } elseif ($HTTP_CODE -eq 503) {
            Write-Host "✗ HTTP $HTTP_CODE (Service unavailable)" -ForegroundColor Red
        } else {
            Write-Host "? HTTP $HTTP_CODE" -ForegroundColor Gray
        }
    } catch {
        Write-Host "✗ ERROR: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Testing health check paths:" -ForegroundColor Green
Write-Host "---------------------------" -ForegroundColor Green
foreach ($PATH in $HEALTH_PATHS) {
    Write-Host -NoNewline "Testing $PATH ... " -ForegroundColor Cyan
    try {
        $response = Invoke-WebRequest -Uri "$CLOUDFRONT_URL$PATH" -Method GET -TimeoutSec 10 -ErrorAction SilentlyContinue -SkipHttpErrorCheck
        $HTTP_CODE = $response.StatusCode
        
        if ($HTTP_CODE -eq 200 -or $HTTP_CODE -eq 204) {
            Write-Host "✓ HTTP $HTTP_CODE (Healthy)" -ForegroundColor Green
        } elseif ($HTTP_CODE -eq 401 -or $HTTP_CODE -eq 403) {
            Write-Host "⚠ HTTP $HTTP_CODE (Auth required - backend is reachable)" -ForegroundColor Yellow
        } elseif ($HTTP_CODE -eq 404) {
            Write-Host "✗ HTTP $HTTP_CODE (Not found)" -ForegroundColor Red
        } elseif ($HTTP_CODE -eq 503) {
            Write-Host "✗ HTTP $HTTP_CODE (Service unavailable)" -ForegroundColor Red
        } else {
            Write-Host "? HTTP $HTTP_CODE" -ForegroundColor Gray
        }
    } catch {
        Write-Host "✗ ERROR: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Checking ALB Target Health" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

$ALB_ARN = "arn:aws:elasticloadbalancing:eu-central-1:550347237240:loadbalancer/app/k8s-pgvnextsharedalb-6273fe7ae1/1d8e5828b868acdb"

# Get target groups
$TG_ARNS = aws elbv2 describe-target-groups --load-balancer-arn $ALB_ARN --query "TargetGroups[].TargetGroupArn" --output text

Write-Host "Target Group Health Status:" -ForegroundColor Green
Write-Host "---------------------------" -ForegroundColor Green
foreach ($TG_ARN in $TG_ARNS -split '\s+') {
    if ([string]::IsNullOrEmpty($TG_ARN)) { continue }
    
    $TG_NAME = aws elbv2 describe-target-groups --target-group-arns $TG_ARN --query "TargetGroups[0].TargetGroupName" --output text
    Write-Host ""
    Write-Host "Target Group: $TG_NAME" -ForegroundColor Cyan
    
    $HEALTH_JSON = aws elbv2 describe-target-health --target-group-arn $TG_ARN --output json | ConvertFrom-Json
    $TOTAL_COUNT = $HEALTH_JSON.TargetHealthDescriptions.Count
    
    if ($TOTAL_COUNT -eq 0) {
        Write-Host "  Status: NO TARGETS REGISTERED" -ForegroundColor Red
    } else {
        $HEALTHY_COUNT = ($HEALTH_JSON.TargetHealthDescriptions | Where-Object { $_.TargetHealth.State -eq "healthy" }).Count
        Write-Host "  Healthy: $HEALTHY_COUNT / $TOTAL_COUNT" -ForegroundColor Yellow
        
        foreach ($target in $HEALTH_JSON.TargetHealthDescriptions) {
            $STATE = $target.TargetHealth.State
            $IP = $target.Target.Id
            $PORT = $target.Target.Port
            
            if ($STATE -eq "healthy") {
                Write-Host "  - $IP`:$PORT -> $STATE" -ForegroundColor Green
            } elseif ($STATE -eq "initial") {
                Write-Host "  - $IP`:$PORT -> $STATE (warming up)" -ForegroundColor Yellow
            } else {
                Write-Host "  - $IP`:$PORT -> $STATE" -ForegroundColor Red
                if ($target.TargetHealth.Reason) {
                    Write-Host "    Reason: $($target.TargetHealth.Reason)" -ForegroundColor Red
                }
            }
        }
    }
}

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Summary" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Architecture Status:" -ForegroundColor Yellow
Write-Host "  ✓ CloudFront: d3d9sb62vwrxui.cloudfront.net" -ForegroundColor White
Write-Host "  ✓ API Gateway: w9p0mqm2i3" -ForegroundColor White
Write-Host "  ✓ VPC Link: cofx2t" -ForegroundColor White
Write-Host "  ✓ ALB: k8s-pgvnextsharedalb-6273fe7ae1" -ForegroundColor White
Write-Host "  ✓ Integration: CloudFront -> API Gateway -> ALB -> Pods" -ForegroundColor White
Write-Host ""

# Final status check
try {
    $response = Invoke-WebRequest -Uri "$CLOUDFRONT_URL/checkout" -Method GET -TimeoutSec 10 -ErrorAction SilentlyContinue -SkipHttpErrorCheck
    $STATUS_CODE = $response.StatusCode
    
    if ($response.Content -match "Service Unavailable") {
        Write-Host "⚠ WARNING: Getting 503 errors - check pod/service status" -ForegroundColor Yellow
    } elseif ($STATUS_CODE -eq 401 -or $STATUS_CODE -eq 403) {
        Write-Host "✓ SUCCESS: Requests reaching backend pods (401/403 = auth required)" -ForegroundColor Green
    } elseif ($STATUS_CODE -eq 200 -or $STATUS_CODE -eq 201) {
        Write-Host "✓ SUCCESS: Full end-to-end flow working!" -ForegroundColor Green
    } else {
        Write-Host "? Status unclear (HTTP $STATUS_CODE) - manual verification needed" -ForegroundColor Gray
    }
} catch {
    Write-Host "? Status unclear - manual verification needed" -ForegroundColor Gray
}

Write-Host ""
