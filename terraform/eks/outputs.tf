output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "eks_cluster_ca_certificate" {
  value = module.eks.cluster_ca_certificate
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

# VPC and Subnet Outputs
output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = module.eks.private_subnet_ids
}
