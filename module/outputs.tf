output "cluster_endpoint" {
  value = aws_eks_cluster.eks[0].endpoint
}

output "cluster_ca_certificate" {
  value = aws_eks_cluster.eks[0].certificate_authority[0].data
}

output "cluster_name" {
  value = aws_eks_cluster.eks[0].name
}

output "vpc_id" {
  description = "VPC ID where EKS cluster is deployed"
  value       = aws_vpc.vpc.id
}

# OIDC provider outputs for IRSA integrations (e.g., AWS Load Balancer Controller)
output "oidc_provider_arn" {
  description = "ARN of the EKS cluster's IAM OIDC provider"
  value       = aws_iam_openid_connect_provider.eks-oidc.arn
}

output "oidc_provider_url" {
  description = "URL of the EKS cluster's IAM OIDC provider"
  value       = aws_iam_openid_connect_provider.eks-oidc.url
}

output "cluster_oidc_issuer" {
  description = "OIDC issuer URL for the EKS cluster"
  value       = aws_eks_cluster.eks[0].identity[0].oidc[0].issuer
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

output "kafka_bootstrap_brokers_sasl_scram" {
  description = "SASL/SCRAM TLS connection host:port pairs"
  value       = aws_msk_cluster.kafka.bootstrap_brokers_sasl_scram
}

output "kafka_zookeeper_connect_string" {
  description = "Zookeeper connection string"
  value       = aws_msk_cluster.kafka.zookeeper_connect_string
}

output "kafka_security_group_id" {
  description = "Security group ID for Kafka cluster"
  value       = aws_security_group.kafka_sg.id
}

# ELK (OpenSearch) Outputs
output "elk_domain_endpoint" {
  description = "Domain-specific endpoint used to submit index, search, and data upload requests"
  value       = aws_opensearch_domain.elk.endpoint
}

output "elk_domain_arn" {
  description = "ARN of the OpenSearch domain"
  value       = aws_opensearch_domain.elk.arn
}

output "elk_dashboard_endpoint" {
  description = "Domain-specific endpoint for OpenSearch Dashboards"
  value       = aws_opensearch_domain.elk.dashboard_endpoint
}

output "elk_domain_id" {
  description = "Unique identifier for the OpenSearch domain"
  value       = aws_opensearch_domain.elk.domain_id
}

output "elk_security_group_id" {
  description = "Security group ID for ELK cluster"
  value       = aws_security_group.opensearch_sg.id
}

output "elk_cloudwatch_log_group_application" {
  description = "CloudWatch log group for OpenSearch application logs"
  value       = aws_cloudwatch_log_group.opensearch_application_logs.name
}

output "elk_cloudwatch_log_group_index" {
  description = "CloudWatch log group for OpenSearch index slow logs"
  value       = aws_cloudwatch_log_group.opensearch_index_logs.name
}

output "elk_cloudwatch_log_group_search" {
  description = "CloudWatch log group for OpenSearch search slow logs"
  value       = aws_cloudwatch_log_group.opensearch_search_logs.name
}

output "elk_cloudwatch_log_group_audit" {
  description = "CloudWatch log group for OpenSearch audit logs"
  value       = aws_cloudwatch_log_group.opensearch_audit_logs.name
}
# VPC and Subnet Outputs
output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = aws_subnet.private-subnet[*].id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = aws_subnet.public-subnet[*].id
}

output "eks_cluster_managed_security_group_id" {
  description = "AWS-managed security group ID for the EKS cluster (used by worker nodes)"
  value       = var.is-eks-cluster-enabled ? aws_eks_cluster.eks[0].vpc_config[0].cluster_security_group_id : null
}
