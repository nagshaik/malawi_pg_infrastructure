# Private API Gateway with CloudFront Architecture

## Overview
This configuration creates a private API Gateway accessible only through CloudFront, providing enhanced security, global distribution, and caching capabilities.

## Architecture Components

### 1. **CloudFront Distribution** (`cloudfront.tf`)
   - **Purpose**: Global CDN providing edge locations worldwide
   - **Domain**: CloudFront-assigned domain (e.g., `d123456abcdef.cloudfront.net`)
   - **Features**:
     - HTTPS only (redirects HTTP to HTTPS)
     - HTTP/2 and HTTP/3 support
     - Custom error pages (403, 404, 500)
     - CloudWatch logging
     - WAF integration

### 2. **WAF Web ACL** (`cloudfront.tf`)
   - **Scope**: CLOUDFRONT (global)
   - **Rules**:
     - Rate limiting (2000 requests per IP)
     - AWS Managed Common Rule Set
     - AWS Managed Known Bad Inputs Rule Set
   - **Purpose**: Protects against common web exploits and DDoS

### 3. **Private API Gateway** (`vpc-link.tf`)
   - **Type**: HTTP API (API Gateway v2)
   - **Access**: Private - only accepts requests with valid CloudFront header
   - **Authorization**: Lambda authorizer validates `x-origin-verify` header
   - **Integration**: VPC Link to internal NLB

### 4. **Lambda Authorizer** (`vpc-link.tf`, `lambda/index.js`)
   - **Purpose**: Validates requests originate from CloudFront
   - **Mechanism**: Verifies secret header value
   - **Runtime**: Node.js 18.x
   - **Header**: `x-origin-verify` with random 32-character secret

### 5. **S3 Bucket for Logs** (`cloudfront.tf`)
   - **Purpose**: Stores CloudFront access logs
   - **Lifecycle**: Automatically deletes logs after 30 days
   - **Security**: Block all public access

## Request Flow

```
Internet → CloudFront → [WAF Rules] → CloudFront adds secret header 
→ API Gateway → Lambda Authorizer validates header 
→ VPC Link → Internal NLB → EKS Pods
```

## Security Features

1. **Origin Protection**
   - API Gateway only accepts requests with valid secret header
   - Secret header only known to CloudFront and Lambda
   - Direct API Gateway access blocked

2. **WAF Protection**
   - Rate limiting prevents DDoS
   - AWS Managed Rules block common attacks
   - SQL injection, XSS protection

3. **Encryption**
   - TLS 1.2+ enforced
   - End-to-end HTTPS
   - Encrypted CloudWatch logs

4. **Access Control**
   - CloudFront → API Gateway: Secret header validation
   - API Gateway → NLB: VPC Link (private)
   - NLB → EKS: Security groups

## Endpoints

### Production Access
- **CloudFront URL**: `https://<distribution-domain>.cloudfront.net`
  - Use this endpoint for all production traffic
  - Global edge locations for low latency
  - Protected by WAF

### Direct API Gateway (Blocked)
- **API Gateway URL**: `https://<api-id>.execute-api.eu-central-1.amazonaws.com`
  - Returns 403 Forbidden (missing secret header)
  - Only accessible via CloudFront

### Health Check (Public)
- **Health Check**: `https://<distribution-domain>.cloudfront.net/health`
  - No authentication required
  - For monitoring purposes

## Deployment Steps

1. **Initialize Terraform**
   ```powershell
   cd c:\Users\nagin\malawi-pg-infra\eks
   terraform init
   ```

2. **Plan Changes**
   ```powershell
   terraform plan --var-file=dev.tfvars
   ```

3. **Apply Configuration**
   ```powershell
   terraform apply --var-file=dev.tfvars
   ```

4. **Get CloudFront Domain**
   ```powershell
   terraform output cloudfront_distribution_domain
   ```

## Custom Domain (Optional)

To use a custom domain (e.g., `api.yourdomain.com`):

1. **Request ACM Certificate** in us-east-1 (required for CloudFront)
   ```powershell
   aws acm request-certificate `
     --domain-name api.yourdomain.com `
     --validation-method DNS `
     --region us-east-1
   ```

2. **Add Certificate to CloudFront** (uncomment in `cloudfront.tf`):
   ```terraform
   viewer_certificate {
     acm_certificate_arn      = var.acm_certificate_arn
     ssl_support_method       = "sni-only"
     minimum_protocol_version = "TLSv1.2_2021"
   }
   ```

3. **Add Alternate Domain Names**:
   ```terraform
   aliases = ["api.yourdomain.com"]
   ```

4. **Create DNS Record** (Route 53 or your DNS provider):
   ```
   api.yourdomain.com CNAME <cloudfront-domain>.cloudfront.net
   ```

## Monitoring

### CloudWatch Logs
- **CloudFront Logs**: `/aws/cloudfront/malawi-pg-api-distribution`
- **API Gateway Logs**: `/aws/apigateway/malawi-pg-eks-http-api`

### S3 Access Logs
- **Bucket**: `malawi-pg-cloudfront-logs-<account-id>`
- **Prefix**: `cloudfront-logs/`

### Metrics to Monitor
- CloudFront: Requests, Bytes Downloaded, Error Rate (4xx, 5xx)
- WAF: Blocked Requests, Allowed Requests
- API Gateway: Request Count, Latency, Integration Latency, Errors
- Lambda: Invocations, Duration, Errors

## Cost Optimization

### CloudFront
- **Price Class**: `PriceClass_100` (North America + Europe only)
- **Cache Behavior**: Cache static content, bypass API calls
- **Compression**: Enabled to reduce data transfer

### WAF
- **Rules**: Only essential rules enabled
- **Requests**: First 10M requests free, then $0.60 per million

### API Gateway
- **Type**: HTTP API (cheaper than REST API)
- **Throttling**: 5000 burst, 10000 steady-state

## Testing

### Test CloudFront Access (Should work)
```powershell
curl https://<cloudfront-domain>.cloudfront.net/health
```

### Test Direct API Gateway (Should fail with 403)
```powershell
curl https://<api-id>.execute-api.eu-central-1.amazonaws.com/health
```

### Test with Ingress Paths
```powershell
# Checkout API
curl https://<cloudfront-domain>.cloudfront.net/checkout

# Core API
curl https://<cloudfront-domain>.cloudfront.net/core

# Auth API
curl https://<cloudfront-domain>.cloudfront.net/auth
```

## Troubleshooting

### 403 Forbidden Errors
- Check Lambda authorizer logs in CloudWatch
- Verify `x-origin-verify` header is being sent
- Check WAF rules aren't blocking legitimate requests

### 502 Bad Gateway
- Check VPC Link status
- Verify NLB target health
- Check EKS pod availability

### High Latency
- Review CloudFront cache hit ratio
- Check API Gateway integration timeout
- Verify NLB and EKS pod response times

## Security Best Practices

1. **Rotate CloudFront Secret**: Periodically regenerate the secret header
2. **Monitor WAF Logs**: Review blocked requests regularly
3. **Enable GuardDuty**: For advanced threat detection
4. **Use AWS Shield**: For enhanced DDoS protection
5. **Review CloudWatch Alarms**: Set up alerts for anomalies

## Next Steps

1. ✅ Deploy infrastructure with `terraform apply`
2. ✅ Update Ingress service names and ports
3. ✅ Apply Ingress to EKS cluster
4. ⬜ Request ACM certificate for custom domain
5. ⬜ Configure custom domain in CloudFront
6. ⬜ Set up CloudWatch alarms
7. ⬜ Configure backup and disaster recovery
