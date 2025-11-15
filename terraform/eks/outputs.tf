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

# ELK (OpenSearch) Outputs
output "elk_domain_endpoint" {
  description = "OpenSearch domain endpoint for API access"
  value       = module.eks.elk_domain_endpoint
}

output "elk_dashboard_endpoint" {
  description = "OpenSearch Dashboards endpoint for web UI access"
  value       = module.eks.elk_dashboard_endpoint
}

output "elk_domain_arn" {
  description = "ARN of the OpenSearch domain"
  value       = module.eks.elk_domain_arn
}

output "elk_domain_id" {
  description = "Unique identifier for the OpenSearch domain"
  value       = module.eks.elk_domain_id
}

output "elk_security_group_id" {
  description = "Security group ID for the ELK cluster"
  value       = module.eks.elk_security_group_id
}

output "elk_cloudwatch_log_group_application" {
  description = "CloudWatch log group for OpenSearch application logs"
  value       = module.eks.elk_cloudwatch_log_group_application
}

output "elk_cloudwatch_log_group_index" {
  description = "CloudWatch log group for OpenSearch index slow logs"
  value       = module.eks.elk_cloudwatch_log_group_index
}

output "elk_cloudwatch_log_group_search" {
  description = "CloudWatch log group for OpenSearch search slow logs"
  value       = module.eks.elk_cloudwatch_log_group_search
}

output "elk_cloudwatch_log_group_audit" {
  description = "CloudWatch log group for OpenSearch audit logs"
  value       = module.eks.elk_cloudwatch_log_group_audit
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
