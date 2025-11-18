output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "eks_cluster_ca_certificate" {
  value = module.eks.cluster_ca_certificate
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_cluster_role_arn" {
  value = module.eks.eks_cluster_role_arn
}

# ELK EC2 Outputs (Self-Managed)
output "elasticsearch_private_ips" {
  description = "Private IP addresses of Elasticsearch nodes"
  value       = module.eks.elasticsearch_private_ips
}

output "kibana_public_ip" {
  description = "Public IP address of Kibana dashboard"
  value       = module.eks.kibana_public_ip
}

output "kibana_public_url" {
  description = "Public URL for Kibana dashboard (use this to access Kibana)"
  value       = module.eks.kibana_public_url
}

output "elk_snapshot_bucket" {
  description = "S3 bucket for ELK snapshots and backups"
  value       = module.eks.elk_snapshot_bucket
}

# VPC Link and API Gateway Outputs
output "vpc_link_id" {
  description = "ID of the VPC Link for API Gateway"
  value       = aws_apigatewayv2_vpc_link.alb_vpc_link.id
}

output "vpc_link_arn" {
  description = "ARN of the VPC Link"
  value       = aws_apigatewayv2_vpc_link.alb_vpc_link.arn
}

output "api_gateway_id" {
  description = "ID of the API Gateway HTTP API"
  value       = aws_apigatewayv2_api.http_api.id
}

output "api_gateway_endpoint" {
  description = "Public endpoint URL for the API Gateway (use this to access your application)"
  value       = aws_apigatewayv2_stage.default_stage.invoke_url
}

output "api_gateway_arn" {
  description = "ARN of the API Gateway"
  value       = aws_apigatewayv2_api.http_api.arn
}

# VPC and Subnet Outputs
output "private_subnet_ids" {
  description = "List of private subnet IDs for internal ALB placement"
  value       = module.eks.private_subnet_ids
}

# CloudFront Outputs
output "cloudfront_distribution_id" {
  description = "ID of the CloudFront distribution"
  value       = aws_cloudfront_distribution.api_distribution.id
}

output "cloudfront_distribution_domain" {
  description = "Domain name of the CloudFront distribution (use this to access your application)"
  value       = aws_cloudfront_distribution.api_distribution.domain_name
}

output "cloudfront_distribution_arn" {
  description = "ARN of the CloudFront distribution"
  value       = aws_cloudfront_distribution.api_distribution.arn
}

output "cloudfront_waf_acl_id" {
  description = "ID of the CloudFront WAF Web ACL"
  value       = aws_wafv2_web_acl.cloudfront_waf.id
}

output "cloudfront_waf_acl_arn" {
  description = "ARN of the CloudFront WAF Web ACL"
  value       = aws_wafv2_web_acl.cloudfront_waf.arn
}
