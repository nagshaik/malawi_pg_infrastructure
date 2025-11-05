output "cluster_endpoint" {
  value = aws_eks_cluster.eks[0].endpoint
}

output "cluster_ca_certificate" {
  value = aws_eks_cluster.eks[0].certificate_authority[0].data
}

output "cluster_name" {
  value = aws_eks_cluster.eks[0].name
}

output "eks_cluster_role_arn" {
  description = "IAM role ARN used for EKS control plane (cluster role)"
  value       = aws_iam_role.eks-cluster-role[0].arn
  depends_on  = [aws_iam_role.eks-cluster-role]
}

output "bastion_role_arn" {
  description = "IAM role ARN for the bastion EC2 instance"
  value       = aws_iam_role.bastion_role.arn
}

output "bastion_eip_public_ip" {
  description = "Public IP allocated for the bastion host"
  value       = aws_eip.bastion.public_ip
  depends_on  = [aws_eip.bastion]
}

# Redis Outputs
output "redis_primary_endpoint" {
  description = "Primary endpoint address for Redis cluster"
  value       = aws_elasticache_replication_group.redis.primary_endpoint_address
}

output "redis_reader_endpoint" {
  description = "Reader endpoint address for Redis cluster"
  value       = aws_elasticache_replication_group.redis.reader_endpoint_address
}

output "redis_port" {
  description = "Port for Redis cluster"
  value       = aws_elasticache_replication_group.redis.port
}

output "redis_configuration_endpoint" {
  description = "Configuration endpoint for Redis cluster"
  value       = aws_elasticache_replication_group.redis.configuration_endpoint_address
}

output "redis_security_group_id" {
  description = "Security group ID for Redis cluster"
  value       = aws_security_group.redis_sg.id
}

# Kafka MSK Outputs
output "kafka_cluster_arn" {
  description = "ARN of the MSK cluster"
  value       = aws_msk_cluster.kafka.arn
}

output "kafka_cluster_name" {
  description = "Name of the MSK cluster"
  value       = aws_msk_cluster.kafka.cluster_name
}

output "kafka_bootstrap_brokers" {
  description = "Plaintext connection host:port pairs"
  value       = aws_msk_cluster.kafka.bootstrap_brokers
}

output "kafka_bootstrap_brokers_tls" {
  description = "TLS connection host:port pairs"
  value       = aws_msk_cluster.kafka.bootstrap_brokers_tls
}

output "kafka_zookeeper_connect_string" {
  description = "Zookeeper connection string"
  value       = aws_msk_cluster.kafka.zookeeper_connect_string
}

output "kafka_security_group_id" {
  description = "Security group ID for Kafka cluster"
  value       = aws_security_group.kafka_sg.id
}