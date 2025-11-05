# Logstash Deployment Guide

## Overview

This Logstash deployment provides advanced log processing and forwarding from your EKS cluster to OpenSearch. It includes:

- **Multiple Input Methods**: TCP, HTTP, Beats
- **Advanced Filtering**: JSON parsing, field extraction, log level normalization
- **Kubernetes Metadata**: Automatic enrichment with K8s context
- **High Availability**: 2 replicas with auto-scaling (2-5 pods)
- **Performance Tuning**: Optimized for moderate traffic
- **Dead Letter Queue**: Failed messages are saved for replay

## Prerequisites

1. EKS cluster deployed and accessible
2. OpenSearch cluster deployed (from Terraform)
3. `kubectl` configured to access your cluster

## Deployment Steps

### Step 1: Update OpenSearch Credentials

Get your OpenSearch endpoint:
```bash
cd eks
terraform output elk_domain_endpoint
```

Update the secret file `03-secret.yaml`:
```yaml
stringData:
  OPENSEARCH_ENDPOINT: "https://YOUR_ACTUAL_ENDPOINT_HERE"
  OPENSEARCH_USER: "admin"
  OPENSEARCH_PASSWORD: "MalawiELK2025!Secure#"
```

### Step 2: Deploy Logstash

Deploy all manifests in order:

```bash
# Navigate to logstash manifests
cd k8s-manifests/logstash

# Apply all manifests
kubectl apply -f 00-namespace.yaml
kubectl apply -f 01-configmap-config.yaml
kubectl apply -f 02-configmap-pipeline.yaml
kubectl apply -f 03-secret.yaml
kubectl apply -f 06-rbac.yaml
kubectl apply -f 04-deployment.yaml
kubectl apply -f 05-service.yaml
kubectl apply -f 07-pdb.yaml
kubectl apply -f 08-hpa.yaml
```

Or apply all at once:
```bash
kubectl apply -f .
```

### Step 3: Verify Deployment

Check Logstash pods are running:
```bash
kubectl get pods -n logging

# Expected output:
# NAME                        READY   STATUS    RESTARTS   AGE
# logstash-xxxxxxxxx-xxxxx    1/1     Running   0          2m
# logstash-xxxxxxxxx-xxxxx    1/1     Running   0          2m
```

Check logs:
```bash
kubectl logs -n logging -l app=logstash --tail=50
```

Check service:
```bash
kubectl get svc -n logging

# Expected output:
# NAME        TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)
# logstash    ClusterIP   10.100.x.x      <none>        5000/TCP,8080/TCP,5044/TCP,9600/TCP
```

### Step 4: Test Log Forwarding

Test TCP input:
```bash
# Port-forward Logstash service
kubectl port-forward -n logging svc/logstash 5000:5000

# In another terminal, send a test log
echo '{"message":"Test log from terminal","level":"INFO","app":"test"}' | nc localhost 5000
```

Test HTTP input:
```bash
# Port-forward HTTP port
kubectl port-forward -n logging svc/logstash 8080:8080

# Send via curl
curl -X POST http://localhost:8080 \
  -H "Content-Type: application/json" \
  -d '{"message":"Test HTTP log","level":"INFO","app":"test-http"}'
```

## Sending Logs from Applications

### Method 1: TCP Socket (JSON)

Send JSON logs directly to Logstash TCP port (5000):

**Python Example:**
```python
import socket
import json

def send_log(message, level="INFO", app="my-app"):
    log_entry = {
        "message": message,
        "level": level,
        "app": app,
        "timestamp": datetime.utcnow().isoformat()
    }
    
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.connect(("logstash.logging.svc.cluster.local", 5000))
    sock.send(json.dumps(log_entry).encode() + b'\n')
    sock.close()

send_log("Application started", "INFO", "my-app")
```

**Node.js Example:**
```javascript
const net = require('net');

function sendLog(message, level = 'INFO', app = 'my-app') {
  const logEntry = {
    message: message,
    level: level,
    app: app,
    timestamp: new Date().toISOString()
  };
  
  const client = net.connect(5000, 'logstash.logging.svc.cluster.local', () => {
    client.write(JSON.stringify(logEntry) + '\n');
    client.end();
  });
}

sendLog('Application started', 'INFO', 'my-app');
```

**Java Example:**
```java
import java.net.*;
import java.io.*;
import org.json.*;

public class LogstashLogger {
    public static void sendLog(String message, String level, String app) {
        try {
            Socket socket = new Socket("logstash.logging.svc.cluster.local", 5000);
            PrintWriter out = new PrintWriter(socket.getOutputStream(), true);
            
            JSONObject log = new JSONObject();
            log.put("message", message);
            log.put("level", level);
            log.put("app", app);
            log.put("timestamp", Instant.now().toString());
            
            out.println(log.toString());
            socket.close();
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}
```

### Method 2: HTTP POST

Send logs via HTTP (port 8080):

**curl:**
```bash
curl -X POST http://logstash.logging.svc.cluster.local:8080 \
  -H "Content-Type: application/json" \
  -d '{
    "message": "HTTP log entry",
    "level": "INFO",
    "app": "my-app",
    "user_id": "12345"
  }'
```

**Python requests:**
```python
import requests

def send_log_http(message, level="INFO", app="my-app"):
    log_entry = {
        "message": message,
        "level": level,
        "app": app
    }
    
    requests.post(
        "http://logstash.logging.svc.cluster.local:8080",
        json=log_entry
    )

send_log_http("HTTP log message", "INFO", "my-app")
```

### Method 3: Logging Libraries

**Python with python-logstash:**
```bash
pip install python-logstash
```

```python
import logging
import logstash

logger = logging.getLogger('my-app')
logger.setLevel(logging.INFO)

# Add Logstash handler
logger.addHandler(logstash.TCPLogstashHandler(
    'logstash.logging.svc.cluster.local',
    5000,
    version=1
))

# Log messages
logger.info('Application started', extra={'user_id': '12345'})
logger.error('Error occurred', extra={'error_code': 500})
```

**Node.js with winston-logstash:**
```bash
npm install winston winston-logstash
```

```javascript
const winston = require('winston');
const LogstashTransport = require('winston-logstash/lib/winston-logstash-latest');

const logger = winston.createLogger({
  transports: [
    new LogstashTransport({
      host: 'logstash.logging.svc.cluster.local',
      port: 5000
    })
  ]
});

logger.info('Application started', { user_id: '12345' });
logger.error('Error occurred', { error_code: 500 });
```

## Log Format

Logstash processes logs and adds metadata:

### Input Format (from your app):
```json
{
  "message": "User login successful",
  "level": "INFO",
  "app": "auth-service",
  "user_id": "12345",
  "ip_address": "10.0.1.50"
}
```

### Output Format (to OpenSearch):
```json
{
  "@timestamp": "2025-11-05T12:00:00.000Z",
  "message": "User login successful",
  "log_level": "INFO",
  "application": "auth-service",
  "user_id": "12345",
  "ip_address": "10.0.1.50",
  "environment": "malawi-pg",
  "cluster": "malawi-pg-azampay-eks-cluster",
  "region": "eu-central-1",
  "k8s_namespace": "default",
  "k8s_pod": "auth-service-xxx",
  "k8s_container": "auth-service",
  "k8s_node": "ip-10-16-xxx.ec2.internal"
}
```

## Viewing Logs in OpenSearch

### Access OpenSearch Dashboards

1. Get the ALB DNS name:
```bash
terraform output elk_alb_dns_name
```

2. Access from bastion or within VPC:
```bash
http://<alb-dns-name>
```

3. Login with credentials:
   - Username: `admin`
   - Password: `MalawiELK2025!Secure#`

### Create Index Pattern

1. Go to **Stack Management** → **Index Patterns**
2. Create index pattern: `logstash-*`
3. Select `@timestamp` as time field
4. Click **Create index pattern**

### Search Logs

1. Go to **Discover**
2. Select `logstash-*` index pattern
3. Use filters and queries:
   - `log_level: ERROR` - Find all errors
   - `application: "auth-service"` - Filter by app
   - `k8s_namespace: "default"` - Filter by namespace
   - `message: *login*` - Search in message field

### Create Visualizations

1. Go to **Visualize** → **Create visualization**
2. Examples:
   - **Line chart**: Log count over time
   - **Pie chart**: Logs by level (INFO, WARN, ERROR)
   - **Data table**: Top applications by log volume
   - **Heat map**: Errors by time and application

## Monitoring Logstash

### Check Logstash Status

```bash
# Check pod status
kubectl get pods -n logging -l app=logstash

# View logs
kubectl logs -n logging -l app=logstash -f

# Check metrics endpoint
kubectl port-forward -n logging svc/logstash 9600:9600
curl http://localhost:9600/_node/stats
```

### HPA Status

```bash
kubectl get hpa -n logging

# Expected output:
# NAME       REFERENCE             TARGETS           MINPODS   MAXPODS   REPLICAS
# logstash   Deployment/logstash   30%/70%, 50%/80%  2         5         2
```

### Common Issues

**Issue 1: Pods not starting**
```bash
# Check events
kubectl describe pod -n logging <pod-name>

# Check logs
kubectl logs -n logging <pod-name>
```

**Issue 2: Can't connect to OpenSearch**
```bash
# Verify OpenSearch endpoint in secret
kubectl get secret -n logging opensearch-credentials -o yaml

# Test connectivity from pod
kubectl exec -n logging <pod-name> -- curl -k https://YOUR_OPENSEARCH_ENDPOINT
```

**Issue 3: Logs not appearing in OpenSearch**
```bash
# Check Logstash logs for errors
kubectl logs -n logging -l app=logstash | grep -i error

# Verify OpenSearch index
# From bastion or pod with curl:
curl -u admin:password https://YOUR_OPENSEARCH_ENDPOINT/_cat/indices?v
```

## Customization

### Modify Pipeline Configuration

Edit `02-configmap-pipeline.yaml` to customize log processing:

```yaml
# Add custom filters
filter {
  # Your custom grok patterns
  grok {
    match => { "message" => "%{CUSTOM_PATTERN}" }
  }
  
  # Custom field mutations
  mutate {
    add_field => { "custom_field" => "value" }
  }
}
```

Apply changes:
```bash
kubectl apply -f 02-configmap-pipeline.yaml
kubectl rollout restart deployment/logstash -n logging
```

### Scale Logstash

```bash
# Manual scaling
kubectl scale deployment/logstash -n logging --replicas=3

# Or update HPA
kubectl edit hpa/logstash -n logging
```

### Adjust Resources

Edit `04-deployment.yaml`:
```yaml
resources:
  requests:
    memory: "2Gi"    # Increase for higher volume
    cpu: "1000m"
  limits:
    memory: "3Gi"
    cpu: "2000m"
```

## Performance Tuning

### For High Volume (>10k logs/sec):

1. **Increase replicas:**
```bash
kubectl scale deployment/logstash -n logging --replicas=5
```

2. **Increase batch size** in `01-configmap-config.yaml`:
```yaml
pipeline.batch.size: 250
pipeline.workers: 4
```

3. **Increase resources** in `04-deployment.yaml`:
```yaml
resources:
  requests:
    memory: "3Gi"
    cpu: "2000m"
```

### For Low Latency:

1. **Reduce batch delay** in `01-configmap-config.yaml`:
```yaml
pipeline.batch.delay: 10  # Lower = faster but more CPU
```

2. **Disable persistent queue** for in-memory processing:
```yaml
queue.type: memory
```

## Security Best Practices

1. **Rotate OpenSearch Password:**
```bash
# Update secret
kubectl create secret generic opensearch-credentials \
  --from-literal=OPENSEARCH_ENDPOINT="https://..." \
  --from-literal=OPENSEARCH_USER="admin" \
  --from-literal=OPENSEARCH_PASSWORD="NEW_PASSWORD" \
  --namespace=logging \
  --dry-run=client -o yaml | kubectl apply -f -

# Restart Logstash
kubectl rollout restart deployment/logstash -n logging
```

2. **Network Policies:**
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: logstash-policy
  namespace: logging
spec:
  podSelector:
    matchLabels:
      app: logstash
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector: {}
    ports:
    - protocol: TCP
      port: 5000
    - protocol: TCP
      port: 8080
  egress:
  - to:
    - namespaceSelector: {}
    ports:
    - protocol: TCP
      port: 443
```

3. **Use TLS for Inputs** (advanced):
Configure TLS certificates for TCP/HTTP inputs.

## Cost Optimization

1. **Use HPA** (already configured) - scales down during low traffic
2. **Reduce log retention** in OpenSearch ILM policies
3. **Filter unnecessary logs** before sending to Logstash
4. **Use log sampling** for very high-volume applications

## Backup and Disaster Recovery

Logs are automatically stored in OpenSearch with:
- Automated daily snapshots (configured in Terraform)
- 14-day retention (AWS managed)

To backup Logstash configuration:
```bash
kubectl get configmap -n logging -o yaml > logstash-backup.yaml
```

## Support and Troubleshooting

### Debug Mode

Enable debug output in `02-configmap-pipeline.yaml`:
```yaml
output {
  stdout {
    codec => rubydebug
  }
  # ... keep opensearch output
}
```

### Test Configuration

```bash
# Test config syntax locally
docker run --rm -v $(pwd):/config \
  docker.elastic.co/logstash/logstash:8.11.0 \
  --config.test_and_exit -f /config/logstash.conf
```

---

**Last Updated**: November 2025  
**Version**: 1.0  
**Maintained By**: Malawi PG Infrastructure Team
