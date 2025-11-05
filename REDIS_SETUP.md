# Redis ElastiCache Cluster - Multi-AZ Configuration

## Overview
This Redis cluster is configured with Multi-AZ automatic failover for high availability.

## Configuration

### Cluster Details
- **Engine**: Redis 7.1
- **Node Type**: cache.t3.micro (free-tier eligible)
- **Number of Nodes**: 2 (Primary + Replica)
- **Multi-AZ**: Enabled with automatic failover
- **Port**: 6379
- **Deployment**: Private subnets across multiple availability zones

### Network & Security
- **Subnet Group**: Uses private subnets for enhanced security
- **Security Group**: Allows access from:
  - EKS worker nodes (port 6379)
  - Bastion host (port 6379)

### Backup & Maintenance
- **Snapshot Retention**: 5 days
- **Snapshot Window**: 03:00-05:00 UTC
- **Maintenance Window**: Sunday 05:00-07:00 UTC
- **Auto Minor Version Upgrade**: Enabled

### Encryption
- **At Rest Encryption**: Disabled (can be enabled if needed)
- **In Transit Encryption**: Disabled (can be enabled if needed)

## Endpoints

After deployment, you'll have access to:
- **Primary Endpoint**: For write operations
- **Reader Endpoint**: For read operations
- **Configuration Endpoint**: For cluster configuration

These endpoints are available as Terraform outputs:
```bash
terraform output redis_primary_endpoint
terraform output redis_reader_endpoint
terraform output redis_configuration_endpoint
```

## Deployment

### Apply Configuration
```powershell
cd c:\Users\nagin\malawi-pg-infra\eks
terraform init
terraform plan -var-file=dev.tfvars
terraform apply -var-file=dev.tfvars
```

### Get Redis Endpoints
```powershell
# Primary endpoint (write)
terraform output redis_primary_endpoint

# Reader endpoint (read replicas)
terraform output redis_reader_endpoint

# Port
terraform output redis_port
```

## Connecting to Redis

### From EKS Pods

Add these environment variables to your pod configuration:

```yaml
env:
  - name: REDIS_HOST
    value: "<redis_primary_endpoint>"
  - name: REDIS_PORT
    value: "6379"
```

### From Bastion Host

1. SSH to bastion
2. Install redis-cli:
   ```bash
   sudo apt-get update
   sudo apt-get install -y redis-tools
   ```

3. Connect to Redis:
   ```bash
   redis-cli -h <redis_primary_endpoint> -p 6379
   ```

4. Test connection:
   ```bash
   redis-cli -h <redis_primary_endpoint> -p 6379 ping
   # Should return: PONG
   ```

## Redis Commands Examples

```bash
# Set a key
SET mykey "Hello Redis"

# Get a key
GET mykey

# Check cluster info
INFO replication

# List all keys
KEYS *

# Monitor commands in real-time
MONITOR
```

## Multi-AZ Failover

The cluster is configured with:
- **Automatic Failover**: Enabled
- **Multi-AZ**: Enabled across eu-central-1a and eu-central-1b

If the primary node fails:
1. ElastiCache automatically detects the failure
2. Promotes the replica to primary
3. Creates a new replica in another AZ
4. Your application continues with minimal interruption

## Monitoring

### CloudWatch Metrics
Monitor these key metrics in CloudWatch:
- `CPUUtilization`
- `DatabaseMemoryUsagePercentage`
- `NetworkBytesIn/Out`
- `CurrConnections`
- `Evictions`
- `CacheHits` / `CacheMisses`

### Check Replication Status
```bash
redis-cli -h <primary_endpoint> -p 6379 INFO replication
```

## Cost Optimization

Current configuration uses `cache.t3.micro` which is free-tier eligible:
- 750 hours/month of cache.t3.micro nodes (for 12 months)

For production workloads, consider:
- `cache.t3.small` - 1.5 GB memory
- `cache.t3.medium` - 3.17 GB memory
- `cache.r7g.large` - 13.07 GB memory (for memory-intensive workloads)

## Cleanup

To remove the Redis cluster:
```powershell
cd c:\Users\nagin\malawi-pg-infra\eks
terraform destroy -var-file=dev.tfvars -target=module.eks-main.aws_elasticache_replication_group.redis
```

## Troubleshooting

### Cannot connect from EKS pods
- Check security group rules allow traffic from EKS node security group
- Verify pods are in the same VPC
- Check Redis endpoint is correct

### High memory usage
- Monitor eviction metrics
- Consider upgrading node type
- Implement TTL for keys
- Review data structure usage

### Slow performance
- Check network latency
- Monitor CPU utilization
- Review command patterns
- Consider read replicas for read-heavy workloads

## Security Best Practices

1. **Enable Encryption** (for production):
   - Set `redis_at_rest_encryption_enabled = true`
   - Set `redis_transit_encryption_enabled = true`

2. **Use Auth Token** (for production):
   - Add auth token for authentication
   - Rotate tokens regularly

3. **Network Isolation**:
   - Keep Redis in private subnets
   - Limit security group access to necessary sources only

4. **Regular Backups**:
   - Current: 5 days retention
   - Increase for production workloads

## Additional Resources

- [AWS ElastiCache for Redis Documentation](https://docs.aws.amazon.com/elasticache/latest/red-ug/)
- [Redis Commands Reference](https://redis.io/commands/)
- [Best Practices for ElastiCache](https://docs.aws.amazon.com/elasticache/latest/red-ug/BestPractices.html)
