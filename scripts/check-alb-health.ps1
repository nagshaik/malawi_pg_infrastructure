# Script to check ALB target health and service status

$ALB_ARN = "arn:aws:elasticloadbalancing:eu-central-1:550347237240:loadbalancer/app/k8s-pgvnextsharedalb-6273fe7ae1/1d8e5828b868acdb"

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Checking ALB and Target Health Status" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

# Get all target groups
Write-Host "Getting target groups..." -ForegroundColor Green
$TARGET_GROUPS = aws elbv2 describe-target-groups --load-balancer-arn $ALB_ARN --query "TargetGroups[].TargetGroupArn" --output text

if ([string]::IsNullOrEmpty($TARGET_GROUPS)) {
    Write-Host "ERROR: No target groups found for ALB" -ForegroundColor Red
    exit 1
}

$TG_ARRAY = $TARGET_GROUPS -split '\s+'

Write-Host "Found $($TG_ARRAY.Count) target groups" -ForegroundColor Yellow
Write-Host ""

# Check health of each target group
foreach ($TG_ARN in $TG_ARRAY) {
    $TG_NAME = ($TG_ARN -split '/')[-1]
    Write-Host "Target Group: $TG_NAME" -ForegroundColor Cyan
    
    $HEALTH = aws elbv2 describe-target-health --target-group-arn $TG_ARN --output json | ConvertFrom-Json
    
    if ($HEALTH.TargetHealthDescriptions.Count -eq 0) {
        Write-Host "  Status: NO TARGETS REGISTERED" -ForegroundColor Red
    } else {
        foreach ($TARGET in $HEALTH.TargetHealthDescriptions) {
            $STATUS = $TARGET.TargetHealth.State
            $IP = $TARGET.Target.Id
            $PORT = $TARGET.Target.Port
            
            if ($STATUS -eq "healthy") {
                Write-Host "  ✓ $IP:$PORT - $STATUS" -ForegroundColor Green
            } elseif ($STATUS -eq "initial") {
                Write-Host "  ⟳ $IP:$PORT - $STATUS (warming up)" -ForegroundColor Yellow
            } else {
                Write-Host "  ✗ $IP:$PORT - $STATUS" -ForegroundColor Red
                if ($TARGET.TargetHealth.Reason) {
                    Write-Host "    Reason: $($TARGET.TargetHealth.Reason)" -ForegroundColor Red
                }
                if ($TARGET.TargetHealth.Description) {
                    Write-Host "    Description: $($TARGET.TargetHealth.Description)" -ForegroundColor Red
                }
            }
        }
    }
    Write-Host ""
}

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Checking Kubernetes Services and Pods" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

# Check services
Write-Host "Services in pgvnext namespaces:" -ForegroundColor Green
kubectl get svc --all-namespaces | Select-String "pgvnext|prod-app"

Write-Host ""
Write-Host "Pods in pgvnext namespaces:" -ForegroundColor Green
kubectl get pods --all-namespaces | Select-String "pgvnext|prod-app"

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Testing ALB directly (bypass CloudFront/API Gateway)" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

$ALB_DNS = "internal-k8s-pgvnextsharedalb-6273fe7ae1-1648604953.eu-central-1.elb.amazonaws.com"

Write-Host "Testing paths on ALB..." -ForegroundColor Yellow
Write-Host "Note: This will fail if ALB is internal and you're testing from outside VPC" -ForegroundColor Gray
Write-Host ""

$PATHS = @("/checkout", "/callback", "/consumer", "/c2b", "/admin", "/adminservice", "/authenticator")

foreach ($PATH in $PATHS) {
    Write-Host "Testing $PATH..." -ForegroundColor Cyan
    try {
        $RESPONSE = curl -s -o /dev/null -w "%{http_code}" "http://$ALB_DNS$PATH" 2>$null
        if ($RESPONSE -eq "200") {
            Write-Host "  ✓ $PATH - HTTP $RESPONSE" -ForegroundColor Green
        } else {
            Write-Host "  ✗ $PATH - HTTP $RESPONSE" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "  ✗ $PATH - Connection failed (expected for internal ALB)" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Summary" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "If targets are healthy, proceed with:" -ForegroundColor Yellow
Write-Host "  1. Run update-api-gateway-alb.ps1 to connect API Gateway" -ForegroundColor White
Write-Host "  2. Test via CloudFront: curl https://d3d9sb62vwrxui.cloudfront.net/checkout" -ForegroundColor White
Write-Host ""
