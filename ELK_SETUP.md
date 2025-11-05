# ELK Stack (OpenSearch) Setup Guide

## Overview

This guide provides comprehensive information about the production-grade ELK (Elasticsearch, Logstash, Kibana) stack implementation using Amazon OpenSearch Service for the Malawi PG Infrastructure.

## Architecture

### Cluster Topology

The ELK cluster is configured with a production-grade architecture following AWS best practices:

#### **Dedicated Master Nodes (3x r6g.large.search)**
- **Purpose**: Cluster management, state coordination, and preventing split-brain scenarios
- **High Availability**: 3 nodes ensure quorum even if one fails
- **No Data Storage**: Focus solely on cluster orchestration
- **Best Practice**: Always use dedicated masters in production

#### **Data Nodes (3x r6g.large.search)**
- **Purpose**: Store data and handle search/indexing operations
- **Multi-AZ Deployment**: Distributed across 2 availability zones
- **Storage**: 100GB gp3 EBS volumes per node (3000 IOPS, 125 MB/s throughput)
- **Auto-scaling**: Handles indexing and query load

#### **Warm Nodes (Optional - UltraWarm)**
- **Purpose**: Cost-effective storage for older, less frequently accessed data
- **Configuration**: Can be enabled by setting `elk_warm_enabled = true`
- **Cost Savings**: Up to 90% reduction for cold/warm data
- **Instance Type**: ultrawarm1.medium.search (configurable)

### Network Architecture

```
Internet/VPC
    ↓ (HTTPS - 443)
[Security Group: elk_sg]
    ↓
[OpenSearch Domain - VPC Mode]
    ├── Private Subnet AZ-A
    │   ├── Master Node 1
    │   └── Data Node 1
    └── Private Subnet AZ-B
        ├── Master Node 2
        ├── Master Node 3
        ├── Data Node 2
        └── Data Node 3
```

## Security Features

### 1. **Encryption**
- **At Rest**: AWS KMS encryption for all data volumes
- **In Transit**: Node-to-node TLS encryption
- **Client Communication**: TLS 1.2+ enforced (Policy-Min-TLS-1-2-2019-07)

### 2. **Fine-Grained Access Control**
- **Master User**: Admin account with full cluster access
- **Internal Database**: User authentication within OpenSearch
- **Role-Based Access**: Can be configured for different users/applications
- **Password Policy**: Minimum 8 characters with uppercase, lowercase, number, and special character

### 3. **Network Isolation**
- **VPC Deployment**: No public endpoint exposure
- **Security Group**: Restricts access to VPC CIDR and bastion host
- **Private Subnets**: Data nodes deployed in private subnets only

### 4. **Access Policy**
```json
{
  "Effect": "Allow",
  "Principal": {
    "AWS": "*"
  },
  "Action": "es:*",
  "Resource": "arn:aws:es:region:account:domain/domain-name/*",
  "Condition": {
    "IpAddress": {
      "aws:SourceIp": ["10.16.0.0/16"]
    }
  }
}
```

## Monitoring & Observability

### CloudWatch Logs

Four types of logs are published to CloudWatch:

1. **Application Logs** (`/aws/opensearch/malawi-pg-elk/application-logs`)
   - General application events
   - Cluster state changes
   - Node failures

2. **Index Slow Logs** (`/aws/opensearch/malawi-pg-elk/index-slow-logs`)
   - Indexing operations exceeding thresholds
   - Helps identify slow indexing patterns

3. **Search Slow Logs** (`/aws/opensearch/malawi-pg-elk/search-slow-logs`)
   - Search queries exceeding thresholds
   - Query performance optimization

4. **Audit Logs** (`/aws/opensearch/malawi-pg-elk/audit-logs`)
   - Authentication attempts
   - Access control events
   - Compliance tracking

**Retention**: 30 days (configurable)

### CloudWatch Alarms

Five critical alarms monitor cluster health:

#### 1. **Cluster Status RED**
- **Threshold**: Status.red >= 1
- **Evaluation**: 1 minute
- **Impact**: Primary shards unavailable, data loss risk
- **Action**: Immediate investigation required

#### 2. **Cluster Status YELLOW**
- **Threshold**: Status.yellow >= 1
- **Evaluation**: 5 minutes
- **Impact**: Replica shards unavailable, reduced redundancy
- **Action**: Monitor and investigate

#### 3. **Low Free Storage**
- **Threshold**: FreeStorageSpace < 10,000 MB
- **Evaluation**: 5 minutes over 15 minutes
- **Impact**: Risk of disk full, write operations may fail
- **Action**: Increase volume size or clean old data

#### 4. **High CPU Utilization**
- **Threshold**: CPUUtilization > 80%
- **Evaluation**: Average over 15 minutes
- **Impact**: Performance degradation
- **Action**: Scale up instances or optimize queries

#### 5. **High JVM Memory Pressure**
- **Threshold**: JVMMemoryPressure > 85%
- **Evaluation**: Maximum over 5 minutes
- **Impact**: Risk of OutOfMemoryError, cluster instability
- **Action**: Scale up instances or reduce heap usage

## Access Methods

### 1. OpenSearch Dashboards (Kibana)

**Endpoint**: `https://<elk_dashboard_endpoint>` (found in Terraform outputs)

**Access Steps**:
1. Connect to bastion host or use VPN
2. Navigate to OpenSearch Dashboards endpoint
3. Login with master credentials:
   - Username: `admin`
   - Password: (from `elk_master_password` variable)

**Features**:
- Discover: Explore and search data
- Visualize: Create charts and graphs
- Dashboard: Build comprehensive dashboards
- Dev Tools: Execute OpenSearch queries
- Stack Management: Index patterns, saved objects

### 2. REST API

**Base URL**: `https://<elk_domain_endpoint>`

#### Example: Index a Document

```bash
curl -XPOST "https://<elk_domain_endpoint>/my-index/_doc" \
  -u admin:password \
  -H 'Content-Type: application/json' \
  -d '{
    "timestamp": "2025-01-10T12:00:00",
    "message": "Application log entry",
    "level": "INFO",
    "service": "api-gateway"
  }'
```

#### Example: Search Documents

```bash
curl -XGET "https://<elk_domain_endpoint>/my-index/_search" \
  -u admin:password \
  -H 'Content-Type: application/json' \
  -d '{
    "query": {
      "match": {
        "level": "ERROR"
      }
    }
  }'
```

### 3. Python Client

```python
from opensearchpy import OpenSearch

# Initialize client
client = OpenSearch(
    hosts=['https://<elk_domain_endpoint>'],
    http_auth=('admin', 'password'),
    use_ssl=True,
    verify_certs=True,
    ssl_show_warn=False
)

# Index a document
response = client.index(
    index='my-index',
    body={
        'timestamp': '2025-01-10T12:00:00',
        'message': 'Application log entry',
        'level': 'INFO',
        'service': 'api-gateway'
    }
)
print(response)

# Search documents
response = client.search(
    index='my-index',
    body={
        'query': {
            'match': {
                'level': 'ERROR'
            }
        }
    }
)
print(response)
```

### 4. Java Client

```java
import org.opensearch.client.opensearch.OpenSearchClient;
import org.opensearch.client.opensearch.core.IndexRequest;
import org.opensearch.client.opensearch.core.SearchRequest;
import org.opensearch.client.transport.httpclient5.ApacheHttpClient5TransportBuilder;
import org.apache.http.HttpHost;
import org.apache.http.auth.AuthScope;
import org.apache.http.auth.UsernamePasswordCredentials;
import org.apache.http.impl.client.BasicCredentialsProvider;

// Create client
BasicCredentialsProvider credentialsProvider = new BasicCredentialsProvider();
credentialsProvider.setCredentials(
    AuthScope.ANY, 
    new UsernamePasswordCredentials("admin", "password")
);

OpenSearchClient client = new OpenSearchClient(
    ApacheHttpClient5TransportBuilder
        .builder(HttpHost.create("https://<elk_domain_endpoint>"))
        .setHttpClientConfigCallback(httpClientBuilder -> 
            httpClientBuilder.setDefaultCredentialsProvider(credentialsProvider))
        .build()
);

// Index document
IndexRequest<Object> indexRequest = new IndexRequest.Builder<>()
    .index("my-index")
    .document(Map.of(
        "timestamp", "2025-01-10T12:00:00",
        "message", "Application log entry",
        "level", "INFO",
        "service", "api-gateway"
    ))
    .build();

client.index(indexRequest);

// Search documents
SearchRequest searchRequest = new SearchRequest.Builder()
    .index("my-index")
    .query(q -> q
        .match(m -> m
            .field("level")
            .query("ERROR")
        )
    )
    .build();

var response = client.search(searchRequest, Object.class);
```

### 5. Node.js Client

```javascript
const { Client } = require('@opensearch-project/opensearch');

// Create client
const client = new Client({
  node: 'https://<elk_domain_endpoint>',
  auth: {
    username: 'admin',
    password: 'password'
  },
  ssl: {
    rejectUnauthorized: true
  }
});

// Index a document
async function indexDocument() {
  const response = await client.index({
    index: 'my-index',
    body: {
      timestamp: '2025-01-10T12:00:00',
      message: 'Application log entry',
      level: 'INFO',
      service: 'api-gateway'
    }
  });
  console.log(response);
}

// Search documents
async function searchDocuments() {
  const response = await client.search({
    index: 'my-index',
    body: {
      query: {
        match: {
          level: 'ERROR'
        }
      }
    }
  });
  console.log(response);
}
```

## Index Management Best Practices

### 1. Index Naming Convention

Use time-based indices for better management:
```
logs-application-2025.01.10
logs-application-2025.01.11
metrics-system-2025.01.10
```

Benefits:
- Easy to delete old data
- Better query performance (target specific dates)
- Simplified backup/restore operations

### 2. Index Templates

Create templates for consistent mappings:

```json
PUT _index_template/logs-template
{
  "index_patterns": ["logs-*"],
  "template": {
    "settings": {
      "number_of_shards": 3,
      "number_of_replicas": 1,
      "refresh_interval": "30s"
    },
    "mappings": {
      "properties": {
        "timestamp": { "type": "date" },
        "level": { "type": "keyword" },
        "message": { "type": "text" },
        "service": { "type": "keyword" }
      }
    }
  }
}
```

### 3. Shard Strategy

- **Shard Size**: Target 10-50GB per shard
- **Shard Count**: (Total Data Size / Target Shard Size) / Number of Data Nodes
- **Replica Count**: 1 for production (provides redundancy)

Example for 300GB data with 3 data nodes:
- Shards: (300GB / 30GB) / 3 = 3 shards per index
- Replicas: 1

### 4. Index Lifecycle Management (ILM)

Configure automatic index lifecycle:

```json
PUT _plugins/_ism/policies/logs_policy
{
  "policy": {
    "description": "Logs lifecycle policy",
    "default_state": "hot",
    "states": [
      {
        "name": "hot",
        "actions": [],
        "transitions": [
          {
            "state_name": "warm",
            "conditions": {
              "min_index_age": "7d"
            }
          }
        ]
      },
      {
        "name": "warm",
        "actions": [
          {
            "warm_migration": {}
          }
        ],
        "transitions": [
          {
            "state_name": "delete",
            "conditions": {
              "min_index_age": "90d"
            }
          }
        ]
      },
      {
        "name": "delete",
        "actions": [
          {
            "delete": {}
          }
        ]
      }
    ]
  }
}
```

## Performance Optimization

### 1. Query Optimization

**Use Filters Instead of Queries for Exact Matches**:
```json
{
  "query": {
    "bool": {
      "filter": [
        { "term": { "status": "active" } }
      ]
    }
  }
}
```

**Pagination with Search After**:
```json
{
  "size": 100,
  "query": { "match_all": {} },
  "sort": [{ "timestamp": "asc" }],
  "search_after": [1704902400000]
}
```

**Aggregations with Sampling**:
```json
{
  "query": { "match_all": {} },
  "aggs": {
    "sample": {
      "sampler": {
        "shard_size": 100
      },
      "aggs": {
        "by_status": {
          "terms": { "field": "status" }
        }
      }
    }
  }
}
```

### 2. Indexing Optimization

**Bulk Indexing**:
```bash
curl -XPOST "https://<elk_domain_endpoint>/_bulk" \
  -u admin:password \
  -H 'Content-Type: application/json' \
  --data-binary @bulk_data.json
```

**Refresh Interval**:
```json
PUT /my-index/_settings
{
  "index": {
    "refresh_interval": "30s"
  }
}
```

**Disable Replica During Bulk Load**:
```json
PUT /my-index/_settings
{
  "index": {
    "number_of_replicas": 0
  }
}
```

### 3. Auto-Tune

The cluster has Auto-Tune enabled which automatically:
- Adjusts JVM heap size
- Optimizes memory settings
- Tunes indexing and search performance
- Schedules maintenance: Sundays at 3 AM UTC

## Cost Optimization

### 1. **Use Graviton2 Instances (r6g.large.search)**
- 20-40% better price/performance vs Intel instances
- Lower operational costs
- Current configuration already uses r6g instances

### 2. **Enable UltraWarm for Cold Data**
```terraform
elk_warm_enabled = true
elk_warm_count   = 2
elk_warm_type    = "ultrawarm1.medium.search"
```

Benefits:
- 90% cost reduction for warm data
- Automatic tier management with ILM
- No performance impact on hot data

### 3. **Right-Size Volumes**
- Monitor `FreeStorageSpace` metric
- Increase volume size only when needed
- Use gp3 volumes (better cost/performance than gp2)

### 4. **Implement Index Lifecycle Policies**
- Automatically delete old indices
- Move to warm tier after 7 days
- Reduce storage costs by 60-80%

### 5. **Optimize Replica Count**
- Use 1 replica for production
- Can reduce to 0 for non-critical dev environments

## Backup and Recovery

### 1. Automated Snapshots

**Configuration**:
- Enabled by default
- Schedule: Daily at 3 AM UTC
- Retention: 14 days (AWS managed)

**Manual Snapshot**:
```bash
curl -XPUT "https://<elk_domain_endpoint>/_snapshot/my-snapshot-repo/snapshot-1" \
  -u admin:password \
  -H 'Content-Type: application/json' \
  -d '{
    "indices": "logs-*",
    "ignore_unavailable": true,
    "include_global_state": false
  }'
```

### 2. Restore from Snapshot

```bash
curl -XPOST "https://<elk_domain_endpoint>/_snapshot/my-snapshot-repo/snapshot-1/_restore" \
  -u admin:password \
  -H 'Content-Type: application/json' \
  -d '{
    "indices": "logs-2025.01.01",
    "rename_pattern": "(.+)",
    "rename_replacement": "restored-$1"
  }'
```

### 3. Cross-Region Replication

For disaster recovery, consider:
1. **Cross-Region Snapshots**: Store snapshots in S3 with cross-region replication
2. **Separate OpenSearch Domain**: Deploy secondary domain in another region
3. **Logstash Forwarding**: Send logs to both domains simultaneously

## Troubleshooting

### Issue: Cluster Status RED

**Symptoms**:
- CloudWatch alarm triggered
- Some indices unavailable
- Write operations failing

**Resolution**:
1. Check cluster health:
   ```bash
   curl -XGET "https://<elk_domain_endpoint>/_cluster/health?pretty" -u admin:password
   ```

2. Identify affected indices:
   ```bash
   curl -XGET "https://<elk_domain_endpoint>/_cat/indices?v&health=red" -u admin:password
   ```

3. Check shard allocation:
   ```bash
   curl -XGET "https://<elk_domain_endpoint>/_cat/shards?v" -u admin:password
   ```

4. Possible fixes:
   - Wait for automatic recovery (5-10 minutes)
   - Increase cluster capacity (add nodes)
   - Delete problematic indices if not critical

### Issue: High JVM Memory Pressure

**Symptoms**:
- CloudWatch alarm triggered
- Slow query performance
- Occasional node failures

**Resolution**:
1. Check JVM metrics:
   ```bash
   curl -XGET "https://<elk_domain_endpoint>/_nodes/stats/jvm?pretty" -u admin:password
   ```

2. Reduce heap usage:
   - Clear field data cache: `POST /_cache/clear?fielddata=true`
   - Optimize queries (use filters, pagination)
   - Reduce aggregation bucket counts

3. Scale up:
   ```terraform
   elk_instance_type = "r6g.xlarge.search"  # Double RAM
   ```

### Issue: Slow Search Performance

**Symptoms**:
- Queries taking > 5 seconds
- High CPU utilization
- Search slow logs populated

**Resolution**:
1. Analyze slow queries:
   - Check CloudWatch logs: `/aws/opensearch/malawi-pg-elk/search-slow-logs`
   - Identify common patterns

2. Optimize queries:
   - Use filters instead of queries for exact matches
   - Add query DSL caching
   - Reduce result set size

3. Add more data nodes:
   ```terraform
   elk_instance_count = 5  # Increase from 3
   ```

### Issue: Disk Space Low

**Symptoms**:
- Free storage alarm triggered
- Write operations slowing down
- Risk of cluster lockdown

**Resolution**:
1. Check index sizes:
   ```bash
   curl -XGET "https://<elk_domain_endpoint>/_cat/indices?v&s=store.size:desc" -u admin:password
   ```

2. Delete old indices:
   ```bash
   curl -XDELETE "https://<elk_domain_endpoint>/logs-2024.01.*" -u admin:password
   ```

3. Increase volume size:
   ```terraform
   elk_ebs_volume_size = 200  # Increase from 100GB
   ```

4. Enable Index Lifecycle Management to auto-delete old data

## Security Hardening

### 1. Rotate Master Password

```bash
# Update in Terraform
elk_master_password = "NewSecurePassword123!@#"

# Apply changes
terraform apply
```

### 2. Create Additional Users

```bash
curl -XPUT "https://<elk_domain_endpoint>/_plugins/_security/api/internalusers/readonly_user" \
  -u admin:password \
  -H 'Content-Type: application/json' \
  -d '{
    "password": "SecurePassword123!",
    "backend_roles": ["read_only"]
  }'
```

### 3. Configure IP Allowlist

Update access policy to restrict specific IPs:

```json
{
  "Condition": {
    "IpAddress": {
      "aws:SourceIp": [
        "10.16.0.0/16",
        "203.0.113.0/24"
      ]
    }
  }
}
```

### 4. Enable Audit Logging

Already enabled. Review logs regularly:
- CloudWatch Log Group: `/aws/opensearch/malawi-pg-elk/audit-logs`
- Monitor for unauthorized access attempts
- Set up alerts for suspicious patterns

## Configuration Variables

### Required Variables

| Variable | Description | Default | Production Value |
|----------|-------------|---------|------------------|
| `elk_master_password` | Master user password | - | (Set securely) |

### Core Configuration

| Variable | Description | Default | Notes |
|----------|-------------|---------|-------|
| `elk_engine_version` | OpenSearch version | `OpenSearch_2.11` | Latest stable |
| `elk_instance_type` | Data node instance | `r6g.large.search` | Graviton2 |
| `elk_instance_count` | Number of data nodes | `3` | Multi-AZ |
| `elk_dedicated_master_enabled` | Enable master nodes | `true` | Recommended |
| `elk_dedicated_master_count` | Master node count | `3` | Prevents split-brain |

### Storage Configuration

| Variable | Description | Default | Notes |
|----------|-------------|---------|-------|
| `elk_ebs_volume_size` | Volume size (GB) | `100` | Per node |
| `elk_ebs_volume_type` | Volume type | `gp3` | Best price/perf |
| `elk_ebs_iops` | IOPS | `3000` | gp3 baseline |
| `elk_ebs_throughput` | Throughput (MB/s) | `125` | gp3 baseline |

### Security Configuration

| Variable | Description | Default | Notes |
|----------|-------------|---------|-------|
| `elk_encrypt_at_rest` | Encryption at rest | `true` | Required |
| `elk_node_to_node_encryption` | Node-to-node encryption | `true` | Required |
| `elk_advanced_security_enabled` | Fine-grained access | `true` | Recommended |

### Monitoring Configuration

| Variable | Description | Default | Notes |
|----------|-------------|---------|-------|
| `elk_log_retention_days` | Log retention | `30` | CloudWatch |
| `elk_cpu_alarm_threshold` | CPU alarm (%) | `80` | Performance |
| `elk_jvm_memory_alarm_threshold` | JVM alarm (%) | `85` | Stability |
| `elk_free_storage_alarm_threshold` | Storage alarm (MB) | `10000` | Capacity |

## Terraform Outputs

After deployment, the following outputs are available:

### Get All Outputs
```bash
# View all outputs
terraform output

# Get specific outputs
terraform output elk_domain_endpoint
terraform output elk_dashboard_endpoint
terraform output elk_domain_arn
terraform output elk_domain_id
terraform output elk_security_group_id
terraform output elk_cloudwatch_log_group_application
terraform output elk_cloudwatch_log_group_index
terraform output elk_cloudwatch_log_group_search
terraform output elk_cloudwatch_log_group_audit
```

### Save All Outputs to File
```bash
# Save all outputs to a text file
terraform output > elk_outputs.txt

# Or in JSON format
terraform output -json > elk_outputs.json
```

### Output Descriptions

| Output Name | Description | Usage |
|-------------|-------------|-------|
| `elk_domain_endpoint` | OpenSearch API endpoint | Use for REST API calls and client connections |
| `elk_dashboard_endpoint` | OpenSearch Dashboards UI endpoint | Access via browser for Kibana-style interface |
| `elk_domain_arn` | ARN of the OpenSearch domain | For IAM policies and CloudWatch |
| `elk_domain_id` | Unique domain identifier | For AWS CLI and API operations |
| `elk_security_group_id` | Security group ID | For configuring additional access rules |
| `elk_cloudwatch_log_group_application` | Application logs group | Monitor application-level events |
| `elk_cloudwatch_log_group_index` | Index slow logs group | Analyze slow indexing operations |
| `elk_cloudwatch_log_group_search` | Search slow logs group | Analyze slow search queries |
| `elk_cloudwatch_log_group_audit` | Audit logs group | Security and compliance monitoring |

## Support and Resources

### Documentation
- [Amazon OpenSearch Service](https://docs.aws.amazon.com/opensearch-service/)
- [OpenSearch Documentation](https://opensearch.org/docs/)
- [OpenSearch API Reference](https://opensearch.org/docs/latest/api-reference/)

### Community
- [OpenSearch Forum](https://forum.opensearch.org/)
- [GitHub Issues](https://github.com/opensearch-project/OpenSearch/issues)
- [AWS Support](https://aws.amazon.com/support/)

### Monitoring
- CloudWatch Dashboard: Pre-configured for ELK metrics
- CloudWatch Alarms: 5 critical alarms for proactive monitoring
- CloudWatch Logs: 4 log groups with 30-day retention

---

**Last Updated**: January 2025
**Version**: 1.0
**Maintained By**: Malawi PG Infrastructure Team
