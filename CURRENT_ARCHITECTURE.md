# Current Architecture Summary

**Last Updated**: November 13, 2025

## Architecture Overview

```
CloudFront (d3d9sb62vwrxui.cloudfront.net)
  ↓ (with x-origin-verify header)
Lambda Authorizer (validates CloudFront header)
  ↓
API Gateway HTTP API (w9p0mqm2i3.execute-api.eu-central-1.amazonaws.com)
  ↓ (via VPC Link l379vo)
ALB (internal-k8s-pgvnextsharedalb-6273fe7ae1-1648604953.eu-central-1.elb.amazonaws.com)
  - Created by AWS Load Balancer Controller
  - Uses Ingress resources for routing
  ↓ (path-based routing)
EKS Pods (7 services)
  - /authenticator → authenticator service
  - /checkout → checkout service
  - /callback → callback service
  - /consumer → consumer service
  - /c2b → c2b service
  - /admin → admin service
  - /adminservice → adminservice service
```

## Active Components

### Infrastructure (Terraform)

**EKS Cluster:**
- Version: 1.34
- AWS Load Balancer Controller: v2.7.0 (installed manually)
- IngressClass: `alb`
- Shared ALB group: `pgvnext-shared-alb`

**API Gateway:**
- Type: HTTP API
- Integration: VPC Link to ALB listener ARN
- Authorizer: Lambda function (validates CloudFront header)
- Stage: $default with detailed metrics enabled
- Logging: INFO level with integration status

**CloudFront:**
- Distribution: d3d9sb62vwrxui.cloudfront.net
- Origin: API Gateway
- Custom header: x-origin-verify (validated by Lambda)
- WAF: Enabled

**Monitoring:**
- 5 API Gateway CloudWatch alarms (4xx, 5xx, latency)
- 2 ALB CloudWatch alarms (unhealthy targets, 5xx)
- Detailed metrics enabled on API Gateway stage

### Kubernetes Manifests

**Ingress Resources:**
- 7 Ingress resources (one per service)
- Path-based routing: `/authenticator`, `/checkout`, `/callback`, `/consumer`, `/c2b`, `/admin`, `/adminservice`
- Health checks: `/health/ready` (30s interval)
- Target type: instance
- All services listen on port 8000

## Current Issues

### Application Code Issue (404 Errors)

**Problem:**
- Requests reach applications with path `/authenticator/health/ready`
- Applications only recognize routes at root level (`/health/ready`)
- `UsePathBase("/authenticator")` is in code but not working correctly

**Root Cause:**
- ASP.NET Core middleware not properly configured
- `UsePathBase` must be called before `UseRouting()`
- Requires `UseForwardedHeaders` middleware before `UsePathBase`

**Solution Required (Application Code):**
```csharp
// In Program.cs or Startup.cs - MUST be in this order:
var app = builder.Build();

// 1. FIRST: ForwardedHeaders
app.UseForwardedHeaders(new ForwardedHeadersOptions
{
    ForwardedHeaders = ForwardedHeaders.XForwardedFor | 
                      ForwardedHeaders.XForwardedProto | 
                      ForwardedHeaders.XForwardedHost
});

// 2. SECOND: PathBase
app.UsePathBase("/authenticator");

// 3. Then everything else
app.UseRouting();
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();
```

## Cleaned Up Resources

### Removed Files:
- ❌ `eks/cloudfront-host-routing.tf` - Lambda@Edge config (not needed)
- ❌ `eks/lambda/path-rewriter/` - Lambda@Edge function (not needed)
- ❌ `k8s-manifests/authenticator-with-nginx-sidecar.yaml` - Sidecar reference (not used)
- ❌ `eks/nlb.tf` - NLB resources (replaced by ALB Ingress)
- ❌ `eks/vpc-link.tf.old` - Old VPC Link config
- ❌ `eks/cloudwatch-alarms.tf` - Empty file (monitoring in api-gateway-alb.tf)
- ❌ `HEALTH_CHECK_CONFIG.md` - Outdated health check docs
- ❌ `HEALTH_CHECK_NO_CODE_CHANGE.md` - Outdated health check docs
- ❌ `CLEANUP_SUMMARY.md` - Outdated summary

### Removed Outputs:
- ❌ NLB-related outputs (nlb_dns_name, nlb_arn, nlb_zone_id, etc.)

## Working Components

✅ **Infrastructure:**
- EKS cluster with Load Balancer Controller
- Shared ALB created via Ingress
- API Gateway integrated to ALB via VPC Link
- CloudFront distribution with Lambda authorizer
- All security groups properly configured
- VPC Link in AVAILABLE state

✅ **Routing:**
- CloudFront → API Gateway: Working
- API Gateway → ALB: Working  
- ALB → Pods: Working
- Requests reaching pods with correct paths

✅ **Health Checks:**
- ALB native health checks: Healthy
- All target groups: 4/4 healthy targets

✅ **Monitoring:**
- All CloudWatch alarms: OK state
- Detailed metrics: Enabled
- Access logs: Capturing integration status

## Next Steps

1. **Fix Application Code** (Development Team):
   - Add proper `UseForwardedHeaders` configuration
   - Ensure `UsePathBase` is before `UseRouting()`
   - Rebuild and redeploy image

2. **Verify After Code Fix**:
   ```bash
   curl -i "https://d3d9sb62vwrxui.cloudfront.net/authenticator/health/ready"
   # Should return: 200 OK
   ```

3. **Optional Future Enhancements**:
   - Add custom domain with SSL certificate
   - Configure SNS notifications for CloudWatch alarms
   - Implement rate limiting per service

## File Structure

```
malawi-pg-infra/
├── eks/
│   ├── api-gateway-alb.tf       # API Gateway + VPC Link + ALB integration + Monitoring
│   ├── aws_auth.tf              # Kubernetes AWS auth ConfigMap
│   ├── backend.tf               # S3 backend for Terraform state
│   ├── cloudfront.tf            # CloudFront distribution + WAF
│   ├── dev.tfvars               # Development environment variables
│   ├── lambda/
│   │   └── authorizer.zip       # CloudFront header validation Lambda
│   ├── main.tf                  # EKS cluster configuration
│   ├── outputs.tf               # Infrastructure outputs
│   ├── providers.tf             # AWS provider configuration
│   └── variables.tf             # Input variables
├── k8s-manifests/
│   └── pgvnext-ingress.yaml     # 7 Ingress resources for services
├── module/
│   ├── bastion-iam.tf
│   ├── bastion.tf
│   ├── eks.tf
│   ├── elk.tf
│   ├── gather.tf
│   ├── iam.tf
│   ├── kafka.tf
│   ├── mongodb.tf
│   ├── outputs.tf
│   ├── rds.tf
│   ├── redis.tf
│   ├── variables.tf
│   └── vpc.tf
├── scripts/
│   ├── cleanup_alb.ps1
│   └── patch_aws_auth.ps1
└── README.md
```

## Key Terraform Resources

### api-gateway-alb.tf
- `aws_apigatewayv2_vpc_link.alb_vpc_link` - Connects to ALB
- `aws_apigatewayv2_api.http_api` - HTTP API
- `aws_apigatewayv2_integration.alb_integration` - ALB listener ARN integration
- `aws_apigatewayv2_route.default_route` - Default route with authorizer
- `aws_lambda_function.cloudfront_authorizer` - Header validation
- `aws_apigatewayv2_stage.default_stage` - Stage with detailed metrics
- `aws_cloudwatch_metric_alarm` - 5 API Gateway alarms + 2 ALB alarms

### cloudfront.tf
- `aws_cloudfront_distribution.api_distribution`
- `aws_wafv2_web_acl.cloudfront_waf`
- `random_password.cloudfront_secret`

### main.tf
- `module.eks` - EKS cluster and supporting resources

## Contact

For issues with:
- **Infrastructure**: Check Terraform state and CloudWatch logs
- **Application 404 errors**: Development team needs to fix `UsePathBase` configuration
- **Monitoring**: Check CloudWatch alarms and API Gateway logs

---

**Architecture Status**: ✅ Infrastructure Working | ⚠️ Application Code Fix Required
