# Application Load Balancer for Kibana
# This allows mapping to a custom domain with SSL/TLS

# Security Group for Kibana ALB
resource "aws_security_group" "kibana_alb_sg" {
  name        = "${var.env}-kibana-alb-sg"
  description = "Security group for Kibana ALB"
  vpc_id      = aws_vpc.vpc.id

  # HTTP access from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP access"
  }

  # HTTPS access from anywhere
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS access"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "${var.env}-kibana-alb-sg"
    Env  = var.env
  }
}

# Update Kibana instance security group to allow traffic from ALB
resource "aws_security_group_rule" "kibana_from_alb" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.kibana_alb_sg.id
  security_group_id        = aws_security_group.kibana_sg.id
  description              = "Allow HTTP from Kibana ALB"
}

# Application Load Balancer for Kibana
resource "aws_lb" "kibana_alb" {
  name               = "${var.env}-kibana-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.kibana_alb_sg.id]
  subnets            = aws_subnet.public-subnet[*].id

  enable_deletion_protection = false
  enable_http2               = true
  enable_cross_zone_load_balancing = true

  tags = {
    Name = "${var.env}-kibana-alb"
    Env  = var.env
  }
}

# Target Group for Kibana instance
resource "aws_lb_target_group" "kibana_tg" {
  name     = "${var.env}-kibana-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.vpc.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/api/status"
    protocol            = "HTTP"
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = {
    Name = "${var.env}-kibana-tg"
    Env  = var.env
  }
}

# Attach Kibana instance to target group
resource "aws_lb_target_group_attachment" "kibana_attachment" {
  target_group_arn = aws_lb_target_group.kibana_tg.arn
  target_id        = aws_instance.kibana.id
  port             = 80
}

# HTTP Listener (redirects to HTTPS if SSL certificate is configured)
resource "aws_lb_listener" "kibana_http" {
  load_balancer_arn = aws_lb.kibana_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.kibana_tg.arn
  }

  # Uncomment below to redirect HTTP to HTTPS when certificate is added
  # default_action {
  #   type = "redirect"
  #   redirect {
  #     port        = "443"
  #     protocol    = "HTTPS"
  #     status_code = "HTTP_301"
  #   }
  # }
}

# HTTPS Listener (requires SSL certificate)
# Uncomment this block after creating/importing an ACM certificate
# resource "aws_lb_listener" "kibana_https" {
#   load_balancer_arn = aws_lb.kibana_alb.arn
#   port              = 443
#   protocol          = "HTTPS"
#   ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
#   certificate_arn   = var.kibana_ssl_certificate_arn
#
#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.kibana_tg.arn
#   }
# }

# CloudWatch Alarms for ALB
resource "aws_cloudwatch_metric_alarm" "kibana_alb_unhealthy_targets" {
  alarm_name          = "${var.env}-kibana-alb-unhealthy-targets"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = 0
  alarm_description   = "Alert when Kibana target becomes unhealthy"
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.kibana_alb.arn_suffix
    TargetGroup  = aws_lb_target_group.kibana_tg.arn_suffix
  }

  tags = {
    Name = "${var.env}-kibana-alb-unhealthy"
    Env  = var.env
  }
}

resource "aws_cloudwatch_metric_alarm" "kibana_alb_5xx_errors" {
  alarm_name          = "${var.env}-kibana-alb-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "Alert when Kibana ALB has high 5xx errors"
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.kibana_alb.arn_suffix
  }

  tags = {
    Name = "${var.env}-kibana-alb-5xx"
    Env  = var.env
  }
}
