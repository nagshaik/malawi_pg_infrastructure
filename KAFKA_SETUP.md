# Apache Kafka (Amazon MSK) - Multi-AZ Configuration

## Overview
This Kafka setup uses Amazon MSK (Managed Streaming for Apache Kafka) with Multi-AZ deployment for high availability and durability.

## Configuration

### Cluster Details
- **Kafka Version**: 3.5.1
- **Instance Type**: kafka.t3.small
- **Number of Brokers**: 2 (distributed across 2 AZs)
- **Storage**: 100 GB EBS per broker
- **Deployment**: Private subnets across multiple availability zones

### Network & Security
- **Subnet Group**: Uses private subnets for enhanced security
- **Security Group**: Allows access from VPC CIDR:
  - Port 9092 (Kafka Plaintext)
  - Port 9094 (Kafka TLS)
  - Port 2181 (Zookeeper)
- **Public Access**: Disabled (private cluster)

### Kafka Configuration
- **Auto Create Topics**: Enabled
- **Default Replication Factor**: 2
- **Min In-Sync Replicas**: 1
- **Default Partitions**: 3
- **Encryption in Transit**: TLS enabled
- **Encryption at Rest**: AWS managed keys

### Logging & Monitoring
- **CloudWatch Logs**: Enabled (7-day retention)
- **Enhanced Monitoring**: DEFAULT level
- **Metrics**: Available in CloudWatch

## Deployment

### Apply Configuration
```powershell
cd c:\Users\nagin\malawi-pg-infra\eks
terraform init
terraform plan -var-file=dev.tfvars
terraform apply -var-file=dev.tfvars
```

### Get Kafka Endpoints
```powershell
# Bootstrap brokers (TLS)
terraform output kafka_bootstrap_brokers_tls

# Bootstrap brokers (Plaintext)
terraform output kafka_bootstrap_brokers

# Zookeeper connection string
terraform output kafka_zookeeper_connect_string

# Cluster ARN
terraform output kafka_cluster_arn
```

## Connecting to Kafka

### From EKS Pods

Add these environment variables to your pod configuration:

```yaml
env:
  - name: KAFKA_BOOTSTRAP_SERVERS
    value: "<bootstrap-brokers-tls>:9094"
  - name: KAFKA_SECURITY_PROTOCOL
    value: "SSL"
```

### Connection Configuration

**For TLS (Recommended):**
```
bootstrap.servers=<broker1>:9094,<broker2>:9094
security.protocol=SSL
```

**For Plaintext (Development only):**
```
bootstrap.servers=<broker1>:9092,<broker2>:9092
security.protocol=PLAINTEXT
```

## Using Kafka

### Install Kafka Tools on Bastion

```bash
# Install Java
sudo apt-get update
sudo apt-get install -y default-jdk

# Download Kafka
cd /tmp
wget https://downloads.apache.org/kafka/3.5.1/kafka_2.13-3.5.1.tgz
tar -xzf kafka_2.13-3.5.1.tgz
cd kafka_2.13-3.5.1
```

### Create a Topic

```bash
# Get bootstrap brokers from Terraform output
BOOTSTRAP_SERVERS="<your-bootstrap-brokers-tls>"

# Create topic
bin/kafka-topics.sh --create \
  --bootstrap-server $BOOTSTRAP_SERVERS \
  --replication-factor 2 \
  --partitions 3 \
  --topic test-topic \
  --command-config client-ssl.properties
```

**client-ssl.properties:**
```properties
security.protocol=SSL
```

### List Topics

```bash
bin/kafka-topics.sh --list \
  --bootstrap-server $BOOTSTRAP_SERVERS \
  --command-config client-ssl.properties
```

### Produce Messages

```bash
bin/kafka-console-producer.sh \
  --bootstrap-server $BOOTSTRAP_SERVERS \
  --topic test-topic \
  --producer.config client-ssl.properties
```

### Consume Messages

```bash
bin/kafka-console-consumer.sh \
  --bootstrap-server $BOOTSTRAP_SERVERS \
  --topic test-topic \
  --from-beginning \
  --consumer.config client-ssl.properties
```

### Describe Topic

```bash
bin/kafka-topics.sh --describe \
  --bootstrap-server $BOOTSTRAP_SERVERS \
  --topic test-topic \
  --command-config client-ssl.properties
```

## Programming Examples

### Python (kafka-python)

```python
from kafka import KafkaProducer, KafkaConsumer
import ssl

# Bootstrap servers from Terraform output
bootstrap_servers = '<bootstrap-brokers-tls>:9094'

# SSL context
context = ssl.create_default_context()
context.check_hostname = False
context.verify_mode = ssl.CERT_NONE

# Producer
producer = KafkaProducer(
    bootstrap_servers=bootstrap_servers,
    security_protocol='SSL',
    ssl_context=context,
    value_serializer=lambda v: json.dumps(v).encode('utf-8')
)

# Send message
producer.send('test-topic', {'message': 'Hello Kafka!'})
producer.flush()

# Consumer
consumer = KafkaConsumer(
    'test-topic',
    bootstrap_servers=bootstrap_servers,
    security_protocol='SSL',
    ssl_context=context,
    auto_offset_reset='earliest',
    value_deserializer=lambda m: json.loads(m.decode('utf-8'))
)

for message in consumer:
    print(f"Received: {message.value}")
```

### Java (Spring Kafka)

```java
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.kafka.annotation.KafkaListener;

@Configuration
public class KafkaConfig {
    @Bean
    public ProducerFactory<String, String> producerFactory() {
        Map<String, Object> config = new HashMap<>();
        config.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, "<bootstrap-brokers-tls>:9094");
        config.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, StringSerializer.class);
        config.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, StringSerializer.class);
        config.put(CommonClientConfigs.SECURITY_PROTOCOL_CONFIG, "SSL");
        return new DefaultKafkaProducerFactory<>(config);
    }
    
    @Bean
    public KafkaTemplate<String, String> kafkaTemplate() {
        return new KafkaTemplate<>(producerFactory());
    }
}

@Service
public class KafkaProducerService {
    @Autowired
    private KafkaTemplate<String, String> kafkaTemplate;
    
    public void sendMessage(String topic, String message) {
        kafkaTemplate.send(topic, message);
    }
}

@Service
public class KafkaConsumerService {
    @KafkaListener(topics = "test-topic", groupId = "my-group")
    public void consume(String message) {
        System.out.println("Consumed: " + message);
    }
}
```

### Node.js (kafkajs)

```javascript
const { Kafka } = require('kafkajs');
const fs = require('fs');

const kafka = new Kafka({
    clientId: 'my-app',
    brokers: ['<bootstrap-brokers-tls>:9094'],
    ssl: {
        rejectUnauthorized: false
    }
});

// Producer
const producer = kafka.producer();
await producer.connect();
await producer.send({
    topic: 'test-topic',
    messages: [
        { value: 'Hello Kafka!' }
    ]
});
await producer.disconnect();

// Consumer
const consumer = kafka.consumer({ groupId: 'my-group' });
await consumer.connect();
await consumer.subscribe({ topic: 'test-topic', fromBeginning: true });

await consumer.run({
    eachMessage: async ({ topic, partition, message }) => {
        console.log({
            value: message.value.toString()
        });
    }
});
```

### Go (confluent-kafka-go)

```go
package main

import (
    "fmt"
    "github.com/confluentinc/confluent-kafka-go/kafka"
)

func main() {
    // Producer
    p, err := kafka.NewProducer(&kafka.ConfigMap{
        "bootstrap.servers": "<bootstrap-brokers-tls>:9094",
        "security.protocol": "SSL",
    })
    
    topic := "test-topic"
    p.Produce(&kafka.Message{
        TopicPartition: kafka.TopicPartition{Topic: &topic, Partition: kafka.PartitionAny},
        Value:          []byte("Hello Kafka!"),
    }, nil)
    
    p.Flush(15 * 1000)
    p.Close()
    
    // Consumer
    c, err := kafka.NewConsumer(&kafka.ConfigMap{
        "bootstrap.servers": "<bootstrap-brokers-tls>:9094",
        "group.id":          "my-group",
        "auto.offset.reset": "earliest",
        "security.protocol": "SSL",
    })
    
    c.SubscribeTopics([]string{"test-topic"}, nil)
    
    for {
        msg, err := c.ReadMessage(-1)
        if err == nil {
            fmt.Printf("Message: %s\n", string(msg.Value))
        }
    }
}
```

## Multi-AZ Architecture

The MSK cluster is configured with:
- **2 Broker Nodes**: Distributed across 2 availability zones
- **Replication Factor 2**: Each partition has 2 replicas
- **Min In-Sync Replicas 1**: At least 1 replica must acknowledge writes

### Fault Tolerance
If a broker fails:
1. Kafka automatically elects new partition leaders
2. Clients reconnect to available brokers
3. MSK automatically replaces failed broker nodes
4. Data remains available through replicas

## Monitoring

### CloudWatch Metrics

Monitor these key metrics:
- `CpuIdle` / `CpuSystem` / `CpuUser`
- `KafkaDataLogsDiskUsed`
- `MemoryUsed`
- `NetworkRxPackets` / `NetworkTxPackets`
- `BytesInPerSec` / `BytesOutPerSec`
- `MessagesInPerSec`
- `FetchConsumerTotalTimeMs`
- `ProduceTotalTimeMs`

### Consumer Lag Monitoring

```bash
# Check consumer group lag
bin/kafka-consumer-groups.sh --describe \
  --bootstrap-server $BOOTSTRAP_SERVERS \
  --group my-group \
  --command-config client-ssl.properties
```

### CloudWatch Logs

View broker logs in CloudWatch:
- Log Group: `/aws/msk/malawi-pg-kafka-cluster`
- Streams: One per broker

## Best Practices

### Topic Configuration

```bash
# Create production topic with proper settings
bin/kafka-topics.sh --create \
  --bootstrap-server $BOOTSTRAP_SERVERS \
  --replication-factor 2 \
  --partitions 6 \
  --config min.insync.replicas=1 \
  --config retention.ms=604800000 \
  --config compression.type=snappy \
  --topic production-topic \
  --command-config client-ssl.properties
```

### Producer Best Practices

- Use `acks=all` for critical data
- Enable idempotence: `enable.idempotence=true`
- Set appropriate `batch.size` and `linger.ms`
- Use compression: `compression.type=snappy`
- Implement retry logic
- Handle serialization errors

### Consumer Best Practices

- Use consumer groups for parallel processing
- Set appropriate `max.poll.records`
- Commit offsets after processing
- Handle rebalancing gracefully
- Implement error handling and dead letter queues

### Performance Optimization

- **Partition Count**: Match or exceed consumer count
- **Batch Size**: Tune for throughput vs latency
- **Compression**: Use snappy or lz4 for better performance
- **Replication**: Balance between durability and performance

## Cost Optimization

Current configuration uses `kafka.t3.small`:
- 2 vCPU, 4 GB RAM per broker
- 100 GB EBS storage per broker

For production workloads, consider:
- `kafka.m5.large` - 2 vCPU, 8 GB RAM
- `kafka.m5.xlarge` - 4 vCPU, 16 GB RAM
- `kafka.m5.2xlarge` - 8 vCPU, 32 GB RAM

**Cost Estimate (eu-central-1):**
- 2 x kafka.t3.small brokers: ~$0.12/hour = ~$88/month
- 200 GB EBS storage: ~$20/month
- **Total: ~$108/month**

## Cleanup

To remove the Kafka cluster:
```powershell
cd c:\Users\nagin\malawi-pg-infra\eks
terraform destroy -var-file=dev.tfvars -target=module.eks-main.aws_msk_cluster.kafka
```

## Troubleshooting

### Cannot connect from EKS pods
- Check security group rules allow traffic from VPC CIDR
- Verify pods are in the same VPC
- Check broker endpoints are correct
- Ensure using correct port (9094 for TLS, 9092 for plaintext)

### Topic creation fails
- Verify `auto.create.topics.enable=true` in configuration
- Check IAM permissions for MSK operations
- Review CloudWatch logs for errors

### High latency
- Monitor CloudWatch metrics for CPU/memory usage
- Check network throughput metrics
- Review partition count and consumer group configuration
- Consider upgrading instance type

### Consumer lag growing
- Increase consumer instances
- Optimize consumer processing logic
- Check for network issues
- Review partition distribution

### Disk space issues
- Monitor `KafkaDataLogsDiskUsed` metric
- Adjust retention policies
- Consider increasing EBS volume size
- Enable log compaction for appropriate topics

## Security Recommendations

1. **Use TLS Encryption**:
   - Already configured for client-broker communication
   - In-cluster encryption enabled

2. **Network Isolation**:
   - Cluster in private subnets
   - No public access
   - Access only from VPC

3. **IAM Authentication** (optional upgrade):
   ```hcl
   client_authentication {
     sasl {
       iam = true
     }
   }
   ```

4. **Logging & Auditing**:
   - CloudWatch logs enabled
   - Monitor access patterns
   - Set up alerts for anomalies

5. **Data Retention**:
   - Configure appropriate retention periods
   - Use log compaction for key-based topics
   - Implement data lifecycle policies

## Additional Resources

- [Amazon MSK Documentation](https://docs.aws.amazon.com/msk/)
- [Apache Kafka Documentation](https://kafka.apache.org/documentation/)
- [Kafka Best Practices](https://kafka.apache.org/documentation/#bestpractices)
- [MSK Configuration](https://docs.aws.amazon.com/msk/latest/developerguide/msk-configuration-properties.html)
