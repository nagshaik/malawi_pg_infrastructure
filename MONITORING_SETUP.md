# Service Health Monitoring Setup

## Overview

This document describes the final monitoring approach for the Malawi PG EKS services. Since the ASP.NET Core applications require authentication for all endpoints (including `/health/ready`), we've implemented **ALB native health monitoring** with CloudWatch alarms instead of exposing public health check endpoints.

## Architecture

```
CloudFront → API Gateway (with Lambda authorizer) → VPC Link → ALB → Ingress → Pods
                                                                 ↓
                                                          CloudWatch Alarms
                                                                 ↓
                                                            SNS Topic
```

### Key Decisions

1. **No Public Health Endpoints**: Health routes removed from API Gateway to avoid authentication conflicts
2. **ALB Native Monitoring**: Use AWS Load Balancer Controller's built-in target health checks
3. **CloudWatch Integration**: Monitor ALB metrics and target health via CloudWatch alarms
4. **SNS Notifications**: Alert on unhealthy targets, 5xx errors, slow responses, and rejected connections

## Components

### 1. CloudWatch Alarms (4 total)

#### `malawi-pg-alb-unhealthy-targets`
- **Metric**: UnHealthyHostCount
- **Threshold**: > 0
- **Evaluation**: 2 periods of 60 seconds
- **Action**: Triggers SNS notification when any target becomes unhealthy
- **Recovery**: Sends OK notification when all targets are healthy

#### `malawi-pg-alb-http-5xx-errors`
- **Metric**: HTTPCode_Target_5XX_Count
- **Threshold**: > 10 errors in 5 minutes
- **Evaluation**: 2 periods of 300 seconds
- **Action**: Triggers SNS notification on excessive server errors

#### `malawi-pg-alb-slow-response`
- **Metric**: TargetResponseTime
- **Threshold**: > 5 seconds average
- **Evaluation**: 2 periods of 60 seconds
- **Action**: Triggers SNS notification when responses are slow

#### `malawi-pg-alb-rejected-connections`
- **Metric**: RejectedConnectionCount
- **Threshold**: > 0
- **Evaluation**: 2 periods of 60 seconds
- **Action**: Triggers SNS notification when ALB rejects connections (capacity issue)

### 2. SNS Topic

- **Name**: `malawi-pg-service-health-alerts`
- **Purpose**: Centralized notification channel for all health alarms
- **Encryption**: KMS-encrypted (alias/aws/sns)
- **Subscriptions**: To add email notifications, uncomment the subscription resource in `eks/cloudwatch-alarms.tf`

### 3. CloudWatch Dashboard

- **Name**: `malawi-pg-service-health-dashboard`
- **URL**: https://console.aws.amazon.com/cloudwatch/home?region=eu-central-1#dashboards:name=malawi-pg-service-health-dashboard
- **Widgets**:
  1. **Target Health Status**: Healthy vs Unhealthy target counts (1-min granularity)
  2. **HTTP Response Codes**: 2xx, 4xx, 5xx response counts (5-min granularity)
  3. **Response Time**: Average and P99 response times (1-min granularity)

## Current Status

All alarms are in **OK** state, indicating:
- ✅ All ALB target groups are healthy
- ✅ No excessive 5xx errors
- ✅ Response times are normal
- ✅ No rejected connections

## How It Works

### ALB Target Health Checks

The AWS Load Balancer Controller configures ALB target groups with health checks based on Ingress annotations:

```yaml
alb.ingress.kubernetes.io/healthcheck-path: /health/ready
alb.ingress.kubernetes.io/healthcheck-port: traffic-port
alb.ingress.kubernetes.io/healthcheck-protocol: HTTP
```

These health checks run **internally** between the ALB and pods:
- ALB sends HTTP GET requests to `/health/ready` on each pod
- Pods must respond with HTTP 200 within the configured timeout
- If a pod fails health checks, ALB stops routing traffic to it
- CloudWatch alarms monitor the UnHealthyHostCount metric

### Why This Approach?

1. **No Code Changes Required**: Apps don't need to bypass authentication for health checks
2. **No Sidecar Containers**: No additional containers needed for unauthenticated health endpoints
3. **Native Integration**: Uses AWS's built-in ALB health checking mechanism
4. **Real-Time Monitoring**: CloudWatch alarms provide immediate notifications
5. **Security**: Health check endpoints remain internal to the VPC

### What Was Removed?

- ❌ 15 health check routes from API Gateway (`/checkout/health/ready`, `/callback/health/ready`, etc.)
- ❌ Health check integration with bypass headers (X-Bypass-Auth, X-Health-Check, etc.)
- ❌ Path rewrite logic that was breaking Ingress routing

## Adding Email Notifications

To receive email alerts when alarms trigger:

1. Edit `eks/cloudwatch-alarms.tf`:
```terraform
resource "aws_sns_topic_subscription" "health_alerts_email" {
  topic_arn = aws_sns_topic.health_alerts.arn
  protocol  = "email"
  endpoint  = "your-email@example.com"
}
```

2. Apply Terraform:
```bash
cd eks
terraform plan -var-file dev.tfvars
terraform apply -var-file dev.tfvars
```

3. Check your email and confirm the SNS subscription

## Troubleshooting

### Check Current Alarm States
```bash
aws cloudwatch describe-alarms --alarm-name-prefix "malawi-pg-alb" \
  --query "MetricAlarms[].[AlarmName,StateValue,StateReason]" --output table
```

### Check ALB Target Health (Console)
1. Navigate to EC2 → Load Balancers
2. Select: `k8s-pgvnextsharedalb-6273fe7ae1`
3. Go to "Target Groups" tab
4. Check health status of each target group

### Check ALB Target Health (CLI)
```bash
# Get ALB ARN
aws elbv2 describe-load-balancers \
  --names k8s-pgvnextsharedalb-6273fe7ae1 \
  --query "LoadBalancers[0].LoadBalancerArn" --output text

# Get target groups
aws elbv2 describe-target-groups \
  --load-balancer-arn <ARN> \
  --query "TargetGroups[].[TargetGroupName,HealthCheckPath]" --output table

# Check target health for specific group
aws elbv2 describe-target-health \
  --target-group-arn <TARGET_GROUP_ARN>
```

### View CloudWatch Dashboard
```bash
# Get dashboard URL
terraform output cloudwatch_dashboard_url

# Or construct manually
echo "https://console.aws.amazon.com/cloudwatch/home?region=eu-central-1#dashboards:name=malawi-pg-service-health-dashboard"
```

### Test Alarm (Trigger Unhealthy State)
```bash
# Scale down a deployment to trigger unhealthy targets alarm
kubectl scale deployment/<deployment-name> --replicas=0 -n <namespace>

# Wait 2-3 minutes for alarm to trigger
aws cloudwatch describe-alarms --alarm-names malawi-pg-alb-unhealthy-targets

# Scale back up
kubectl scale deployment/<deployment-name> --replicas=2 -n <namespace>
```

## Related Files

- **Terraform Configuration**: `eks/cloudwatch-alarms.tf`
- **API Gateway Configuration**: `eks/api-gateway-alb.tf` (health routes removed)
- **Ingress Manifests**: `k8s-manifests/pgvnext-ingress.yaml` (healthcheck-path annotations)
- **Alternative Approaches**: `HEALTH_CHECK_NO_CODE_CHANGE.md` (other options considered)

## Next Steps

1. ✅ CloudWatch alarms created and working
2. ✅ SNS topic created
3. ⚠️ Add email subscription to SNS topic (optional)
4. ⚠️ Test alarm by simulating unhealthy targets (optional)
5. ⚠️ Set up additional integrations (PagerDuty, Slack, etc.) via SNS subscriptions (optional)

## Summary

The monitoring setup provides comprehensive health tracking without requiring changes to application code or adding sidecar containers. ALB's native health checks verify that pods are responding correctly, while CloudWatch alarms alert the operations team when issues occur. This approach is clean, maintainable, and follows AWS best practices.
