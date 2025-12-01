# Redis Deployment on EKS

This directory contains Kubernetes manifests for deploying Redis as a StatefulSet in your EKS cluster.

## Architecture

- **2 Redis Pods**: StatefulSet with 2 replicas for high availability
- **Persistent Storage**: 20GB gp3 EBS volumes per pod
- **Password Protected**: Authentication enabled with password
- **Monitoring**: Redis exporter for Prometheus metrics
- **Anti-Affinity**: Pods spread across different nodes

## Configuration

- **Memory**: 2GB max with LRU eviction policy
- **Password**: `MalawiRedis2025!Secure#`
- **Port**: 6379
- **Storage**: 20GB per instance

## Deployment

```bash
# Deploy namespace
kubectl apply -f redis-namespace.yaml

# Deploy ConfigMap
kubectl apply -f redis-configmap.yaml

# Deploy Redis StatefulSet and Services
kubectl apply -f redis-statefulset.yaml

# Deploy monitoring (optional)
kubectl apply -f redis-monitoring.yaml
```

## Connection Strings

**From within the cluster:**
```
redis-service.redis.svc.cluster.local:6379
```

**From application pods:**
```
Host: redis-service.redis
Port: 6379
Password: MalawiRedis2025!Secure#
```

**Individual pods:**
```
redis-0.redis-headless.redis.svc.cluster.local:6379
redis-1.redis-headless.redis.svc.cluster.local:6379
```

## Verify Deployment

```bash
# Check pods
kubectl get pods -n redis

# Check services
kubectl get svc -n redis

# Check storage
kubectl get pvc -n redis

# Test connection
kubectl run redis-test --rm -i --tty --image redis:7.2-alpine -n redis -- redis-cli -h redis-service -a MalawiRedis2025!Secure# ping
```

## Monitoring

Redis metrics are exported on port 9121 and can be scraped by Prometheus:
```
http://redis-exporter.redis.svc.cluster.local:9121/metrics
```

## Scaling

To scale Redis instances:
```bash
kubectl scale statefulset redis --replicas=3 -n redis
```

## Cost Comparison

**AWS ElastiCache (cache.t3.medium × 2)**: ~$99/month
**EKS Redis (on existing nodes)**: ~$8/month (storage only)

**Monthly Savings**: ~$91

## Backup

Redis is configured with RDB persistence:
- Snapshot every 15 minutes if at least 1 key changed
- Snapshot every 5 minutes if at least 10 keys changed
- Snapshot every 1 minute if at least 10000 keys changed

Backups are stored in the persistent volume.

## Performance

Each pod is configured with:
- CPU: 250m request, 1 CPU limit
- Memory: 512Mi request, 2Gi limit
- Storage: 20GB gp3 SSD

## Security

- Password authentication enabled
- Only accessible within cluster (ClusterIP service)
- Network policies can be added for additional security
