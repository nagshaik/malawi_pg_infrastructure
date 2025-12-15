# Kenya EKS ALB Access Logs

To enable ALB access logs for Kenya EKS services managed by AWS Load Balancer Controller, add the following annotation to each Ingress that participates in the shared ALB:

```yaml
metadata:
  annotations:
    alb.ingress.kubernetes.io/load-balancer-attributes: access_logs.s3.enabled=true,access_logs.s3.bucket=kenya-pg-alb-access-logs,access_logs.s3.prefix=eks-alb/
```

- Bucket: `kenya-pg-alb-access-logs`
- Prefix: `eks-alb/`

Ensure the ALB controller is installed and your Ingresses are grouped appropriately:

```yaml
metadata:
  annotations:
    alb.ingress.kubernetes.io/group.name: pgvnext-shared-alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: instance
```

Verify logs in S3 under `s3://kenya-pg-alb-access-logs/eks-alb/AWSLogs/`.
