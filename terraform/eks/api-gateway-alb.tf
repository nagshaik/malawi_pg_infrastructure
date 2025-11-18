# Data source to discover the ALB created by AWS Load Balancer Controller
# This ALB is created when you apply the Ingress resources

data "aws_lb" "ingress_alb" {
  tags = {
    "ingress.k8s.aws/stack" = "pgvnext-shared-alb"
  }

  depends_on = [aws_apigatewayv2_api.http_api]
}

# Data source for ALB listener
data "aws_lb_listener" "ingress_alb_http" {
  load_balancer_arn = data.aws_lb.ingress_alb.arn
  port              = 80
}

# VPC Link for API Gateway to connect to Ingress ALB
resource "aws_apigatewayv2_vpc_link" "alb_vpc_link" {
  name               = "${var.env}-alb-vpc-link"
  security_group_ids = tolist(data.aws_lb.ingress_alb.security_groups)
  subnet_ids         = module.eks.private_subnet_ids

  tags = {
    Name        = "${var.env}-alb-vpc-link"
    Environment = var.env
    ManagedBy   = "Terraform"
    Purpose     = "Connect-API-Gateway-to-Ingress-ALB"
  }
}

# API Gateway HTTP API (Private - accessible only via CloudFront)
resource "aws_apigatewayv2_api" "http_api" {
  name          = "${var.env}-eks-http-api"
  protocol_type = "HTTP"
  description   = "Private HTTP API Gateway accessible only via CloudFront"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    allow_headers = ["*"]
    max_age       = 300
  }

  tags = {
    Name        = "${var.env}-eks-http-api"
    Environment = var.env
    ManagedBy   = "Terraform"
    Access      = "Private-CloudFront-Only"
  }
}

# Integration with Ingress ALB
# Use ALB listener ARN for VPC Link integration (required by API Gateway)
resource "aws_apigatewayv2_integration" "alb_integration" {
  api_id             = aws_apigatewayv2_api.http_api.id
  integration_type   = "HTTP_PROXY"
  integration_method = "ANY"
  integration_uri    = data.aws_lb_listener.ingress_alb_http.arn
  connection_type    = "VPC_LINK"
  connection_id      = aws_apigatewayv2_vpc_link.alb_vpc_link.id

  lifecycle {
    create_before_destroy = true
  }
}

# Note: Health check routes removed from API Gateway
# Apps require authentication and cannot be modified
# Health monitoring uses ALB native target health checks + CloudWatch alarms
# See cloudwatch-alarms.tf for monitoring configuration

# Default route (catch-all) with authorizer
resource "aws_apigatewayv2_route" "default_route" {
  api_id             = aws_apigatewayv2_api.http_api.id
  route_key          = "$default"
  target             = "integrations/${aws_apigatewayv2_integration.alb_integration.id}"
  authorizer_id      = aws_apigatewayv2_authorizer.cloudfront_authorizer.id
  authorization_type = "CUSTOM"
}

# Health check routes removed - apps require authentication
# Use ALB target health monitoring instead (see cloudwatch-alarms.tf)

# Lambda function for CloudFront header verification
resource "aws_lambda_function" "cloudfront_authorizer" {
  filename         = "${path.module}/lambda/authorizer.zip"
  function_name    = "${var.env}-cloudfront-authorizer"
  role             = aws_iam_role.lambda_authorizer.arn
  handler          = "index.handler"
  source_code_hash = filebase64sha256("${path.module}/lambda/authorizer.zip")
  runtime          = "nodejs18.x"
  timeout          = 3

  environment {
    variables = {
      CLOUDFRONT_SECRET = random_password.cloudfront_secret.result
    }
  }

  tags = {
    Name        = "${var.env}-cloudfront-authorizer"
    Environment = var.env
    ManagedBy   = "Terraform"
  }
}

# IAM role for Lambda authorizer
resource "aws_iam_role" "lambda_authorizer" {
  name = "${var.env}-lambda-authorizer-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.env}-lambda-authorizer-role"
    Environment = var.env
    ManagedBy   = "Terraform"
  }
}

# Attach basic execution policy to Lambda role
resource "aws_iam_role_policy_attachment" "lambda_authorizer_basic" {
  role       = aws_iam_role.lambda_authorizer.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda permission for API Gateway
resource "aws_lambda_permission" "api_gateway_authorizer" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cloudfront_authorizer.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*"
}

# API Gateway Authorizer
resource "aws_apigatewayv2_authorizer" "cloudfront_authorizer" {
  api_id           = aws_apigatewayv2_api.http_api.id
  authorizer_type  = "REQUEST"
  authorizer_uri   = aws_lambda_function.cloudfront_authorizer.invoke_arn
  name             = "${var.env}-cloudfront-authorizer"
  identity_sources = ["$request.header.x-origin-verify"]

  authorizer_payload_format_version = "2.0"
  enable_simple_responses           = true
}

# API Gateway Stage (for deployment)
resource "aws_apigatewayv2_stage" "default_stage" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway_logs.arn
    format = jsonencode({
      requestId               = "$context.requestId"
      ip                      = "$context.identity.sourceIp"
      requestTime             = "$context.requestTime"
      httpMethod              = "$context.httpMethod"
      routeKey                = "$context.routeKey"
      status                  = "$context.status"
      protocol                = "$context.protocol"
      responseLength          = "$context.responseLength"
      errorMessage            = "$context.error.message"
      integrationStatus       = "$context.integrationStatus"
      integrationErrorMessage = "$context.integration.error"
    })
  }

  default_route_settings {
    throttling_burst_limit   = 5000
    throttling_rate_limit    = 10000
    detailed_metrics_enabled = true
    logging_level            = "INFO"
  }

  tags = {
    Name        = "${var.env}-api-gateway-stage"
    Environment = var.env
  }
}

# CloudWatch Log Group for API Gateway
resource "aws_cloudwatch_log_group" "api_gateway_logs" {
  name              = "/aws/apigateway/${var.env}-eks-http-api"
  retention_in_days = 7

  tags = {
    Name        = "${var.env}-api-gateway-logs"
    Environment = var.env
    ManagedBy   = "Terraform"
  }
}

# Random password for CloudFront secret header verification
resource "random_password" "cloudfront_secret" {
  length  = 32
  special = true
}

# API Gateway Monitoring - CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "api_gateway_4xx_errors" {
  alarm_name          = "${var.env}-api-gateway-4xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "4XXError"
  namespace           = "AWS/ApiGateway"
  period              = 300
  statistic           = "Sum"
  threshold           = 50
  alarm_description   = "Alert when API Gateway has excessive 4xx errors (client errors)"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ApiId = aws_apigatewayv2_api.http_api.id
    Stage = aws_apigatewayv2_stage.default_stage.name
  }

  tags = {
    Name        = "${var.env}-api-gateway-4xx-alarm"
    Environment = var.env
    ManagedBy   = "Terraform"
  }
}

resource "aws_cloudwatch_metric_alarm" "api_gateway_5xx_errors" {
  alarm_name          = "${var.env}-api-gateway-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "5XXError"
  namespace           = "AWS/ApiGateway"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "Alert when API Gateway has server errors"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ApiId = aws_apigatewayv2_api.http_api.id
    Stage = aws_apigatewayv2_stage.default_stage.name
  }

  tags = {
    Name        = "${var.env}-api-gateway-5xx-alarm"
    Environment = var.env
    ManagedBy   = "Terraform"
  }
}

resource "aws_cloudwatch_metric_alarm" "api_gateway_latency" {
  alarm_name          = "${var.env}-api-gateway-high-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "IntegrationLatency"
  namespace           = "AWS/ApiGateway"
  period              = 300
  statistic           = "Average"
  threshold           = 5000
  alarm_description   = "Alert when API Gateway integration latency exceeds 5 seconds"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ApiId = aws_apigatewayv2_api.http_api.id
    Stage = aws_apigatewayv2_stage.default_stage.name
  }

  tags = {
    Name        = "${var.env}-api-gateway-latency-alarm"
    Environment = var.env
    ManagedBy   = "Terraform"
  }
}

# ALB Monitoring - CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_targets" {
  alarm_name          = "${var.env}-alb-unhealthy-targets"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  alarm_description   = "Alert when any service has unhealthy targets behind the ALB"
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = data.aws_lb.ingress_alb.arn_suffix
  }

  tags = {
    Name        = "${var.env}-alb-unhealthy-alarm"
    Environment = var.env
    ManagedBy   = "Terraform"
  }
}

resource "aws_cloudwatch_metric_alarm" "alb_target_5xx_errors" {
  alarm_name          = "${var.env}-alb-target-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "Alert when ALB targets return excessive 5xx errors"
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = data.aws_lb.ingress_alb.arn_suffix
  }

  tags = {
    Name        = "${var.env}-alb-5xx-alarm"
    Environment = var.env
    ManagedBy   = "Terraform"
  }
}

# Outputs for monitoring URLs
output "api_gateway_metrics_url" {
  description = "CloudWatch metrics URL for API Gateway"
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${var.aws-region}#metricsV2:graph=~();query=~'*7bAWS*2fApiGateway*2cApiId*2cStage*7d*20ApiId*3d*22${aws_apigatewayv2_api.http_api.id}*22"
}

output "alb_metrics_url" {
  description = "CloudWatch metrics URL for ALB"
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${var.aws-region}#metricsV2:graph=~();query=~'*7bAWS*2fApplicationELB*2cLoadBalancer*7d*20LoadBalancer*3d*22${data.aws_lb.ingress_alb.arn_suffix}*22"
}
