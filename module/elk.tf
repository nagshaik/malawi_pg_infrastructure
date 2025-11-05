# Security Group for OpenSearch (ELK)
resource "aws_security_group" "opensearch_sg" {
  name        = "${var.env}-opensearch-sg"
  description = "Security group for OpenSearch cluster"
  vpc_id      = aws_vpc.vpc.id

  # HTTPS access for OpenSearch API and Kibana
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.cidr-block]
    description = "Allow HTTPS access from VPC"
  }

  # Allow access from bastion for management
  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
    description     = "Allow HTTPS access from bastion"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "${var.env}-opensearch-sg"
    Env  = var.env
  }
}

# IAM Service-Linked Role for OpenSearch
resource "aws_iam_service_linked_role" "opensearch" {
  count            = var.elk_create_service_linked_role ? 1 : 0
  aws_service_name = "opensearchservice.amazonaws.com"
  description      = "Service-linked role for Amazon OpenSearch Service"
}

# CloudWatch Log Group for OpenSearch Logs
resource "aws_cloudwatch_log_group" "opensearch_application_logs" {
  name              = "/aws/opensearch/${var.env}-elk-cluster/application-logs"
  retention_in_days = var.elk_log_retention_days

  tags = {
    Name = "${var.env}-opensearch-application-logs"
    Env  = var.env
  }
}

resource "aws_cloudwatch_log_group" "opensearch_index_logs" {
  name              = "/aws/opensearch/${var.env}-elk-cluster/index-logs"
  retention_in_days = var.elk_log_retention_days

  tags = {
    Name = "${var.env}-opensearch-index-logs"
    Env  = var.env
  }
}

resource "aws_cloudwatch_log_group" "opensearch_search_logs" {
  name              = "/aws/opensearch/${var.env}-elk-cluster/search-logs"
  retention_in_days = var.elk_log_retention_days

  tags = {
    Name = "${var.env}-opensearch-search-logs"
    Env  = var.env
  }
}

resource "aws_cloudwatch_log_group" "opensearch_audit_logs" {
  name              = "/aws/opensearch/${var.env}-elk-cluster/audit-logs"
  retention_in_days = var.elk_log_retention_days

  tags = {
    Name = "${var.env}-opensearch-audit-logs"
    Env  = var.env
  }
}

# CloudWatch Log Resource Policy for OpenSearch
resource "aws_cloudwatch_log_resource_policy" "opensearch_log_policy" {
  policy_name = "${var.env}-opensearch-log-policy"

  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "es.amazonaws.com"
        }
        Action = [
          "logs:PutLogEvents",
          "logs:CreateLogStream"
        ]
        Resource = [
          "${aws_cloudwatch_log_group.opensearch_application_logs.arn}:*",
          "${aws_cloudwatch_log_group.opensearch_index_logs.arn}:*",
          "${aws_cloudwatch_log_group.opensearch_search_logs.arn}:*",
          "${aws_cloudwatch_log_group.opensearch_audit_logs.arn}:*"
        ]
      }
    ]
  })
}

# OpenSearch Domain (Production-Grade ELK Stack)
resource "aws_opensearch_domain" "elk" {
  domain_name    = "${var.env}-elk-cluster"
  engine_version = var.elk_engine_version

  # Cluster Configuration - Multi-AZ with Dedicated Master Nodes
  cluster_config {
    # Data Nodes
    instance_type          = var.elk_instance_type
    instance_count         = var.elk_instance_count
    zone_awareness_enabled = var.elk_zone_awareness_enabled

    dynamic "zone_awareness_config" {
      for_each = var.elk_zone_awareness_enabled ? [1] : []
      content {
        availability_zone_count = var.elk_availability_zone_count
      }
    }

    # Dedicated Master Nodes (Production Best Practice)
    dedicated_master_enabled = var.elk_dedicated_master_enabled
    dedicated_master_type    = var.elk_dedicated_master_type
    dedicated_master_count   = var.elk_dedicated_master_count

    # Warm Nodes (Cost Optimization for Older Data)
    warm_enabled = var.elk_warm_enabled
    warm_count   = var.elk_warm_enabled ? var.elk_warm_count : null
    warm_type    = var.elk_warm_enabled ? var.elk_warm_type : null
  }

  # EBS Storage Configuration
  ebs_options {
    ebs_enabled = true
    volume_size = var.elk_ebs_volume_size
    volume_type = var.elk_ebs_volume_type
    iops        = var.elk_ebs_volume_type == "gp3" || var.elk_ebs_volume_type == "io1" ? var.elk_ebs_iops : null
    throughput  = var.elk_ebs_volume_type == "gp3" ? var.elk_ebs_throughput : null
  }

  # VPC Configuration
  vpc_options {
    subnet_ids         = var.elk_zone_awareness_enabled ? [aws_subnet.private-subnet[0].id, aws_subnet.private-subnet[1].id] : [aws_subnet.private-subnet[0].id]
    security_group_ids = [aws_security_group.opensearch_sg.id]
  }

  # Encryption Configuration
  encrypt_at_rest {
    enabled    = var.elk_encrypt_at_rest
    kms_key_id = var.elk_kms_key_id
  }

  node_to_node_encryption {
    enabled = var.elk_node_to_node_encryption
  }

  domain_endpoint_options {
    enforce_https       = true
    tls_security_policy = "Policy-Min-TLS-1-2-2019-07"
  }

  # Advanced Security Options (Fine-Grained Access Control)
  advanced_security_options {
    enabled                        = var.elk_advanced_security_enabled
    internal_user_database_enabled = var.elk_internal_user_database_enabled
    master_user_options {
      master_user_name     = var.elk_master_username
      master_user_password = var.elk_master_password
    }
  }

  # Advanced Options
  advanced_options = {
    "rest.action.multi.allow_explicit_index" = "true"
    "override_main_response_version"         = "false"
  }

  # Logging Configuration
  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.opensearch_application_logs.arn
    log_type                 = "ES_APPLICATION_LOGS"
  }

  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.opensearch_index_logs.arn
    log_type                 = "INDEX_SLOW_LOGS"
  }

  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.opensearch_search_logs.arn
    log_type                 = "SEARCH_SLOW_LOGS"
  }

  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.opensearch_audit_logs.arn
    log_type                 = "AUDIT_LOGS"
    enabled                  = var.elk_advanced_security_enabled
  }

  # Automated Snapshot Configuration
  snapshot_options {
    automated_snapshot_start_hour = var.elk_automated_snapshot_start_hour
  }

  # Auto-Tune Options (Performance Optimization)
  auto_tune_options {
    desired_state       = var.elk_auto_tune_desired_state
    rollback_on_disable = "NO_ROLLBACK"

    maintenance_schedule {
      start_at = var.elk_auto_tune_maintenance_start
      duration {
        value = var.elk_auto_tune_maintenance_duration
        unit  = "HOURS"
      }
      cron_expression_for_recurrence = var.elk_auto_tune_cron_expression
    }
  }

  # Access Policy (VPC-based, no IP restrictions as security group handles access)
  access_policies = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "*"
        }
        Action   = "es:*"
        Resource = "arn:aws:es:${var.aws-region}:*:domain/${var.env}-elk-cluster/*"
      }
    ]
  })

  tags = {
    Name = "${var.env}-elk-cluster"
    Env  = var.env
  }

  depends_on = [
    aws_cloudwatch_log_group.opensearch_application_logs,
    aws_cloudwatch_log_group.opensearch_index_logs,
    aws_cloudwatch_log_group.opensearch_search_logs,
    aws_cloudwatch_log_group.opensearch_audit_logs,
    aws_cloudwatch_log_resource_policy.opensearch_log_policy
  ]
}

# CloudWatch Alarms for Production Monitoring
resource "aws_cloudwatch_metric_alarm" "opensearch_cluster_status_red" {
  alarm_name          = "${var.env}-opensearch-cluster-status-red"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "ClusterStatus.red"
  namespace           = "AWS/ES"
  period              = "60"
  statistic           = "Maximum"
  threshold           = "1"
  alarm_description   = "OpenSearch cluster status is RED"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DomainName = aws_opensearch_domain.elk.domain_name
    ClientId   = data.aws_caller_identity.current.account_id
  }

  tags = {
    Name = "${var.env}-opensearch-red-alarm"
    Env  = var.env
  }
}

resource "aws_cloudwatch_metric_alarm" "opensearch_cluster_status_yellow" {
  alarm_name          = "${var.env}-opensearch-cluster-status-yellow"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "ClusterStatus.yellow"
  namespace           = "AWS/ES"
  period              = "60"
  statistic           = "Maximum"
  threshold           = "1"
  alarm_description   = "OpenSearch cluster status is YELLOW"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DomainName = aws_opensearch_domain.elk.domain_name
    ClientId   = data.aws_caller_identity.current.account_id
  }

  tags = {
    Name = "${var.env}-opensearch-yellow-alarm"
    Env  = var.env
  }
}

resource "aws_cloudwatch_metric_alarm" "opensearch_free_storage_space" {
  alarm_name          = "${var.env}-opensearch-low-storage"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/ES"
  period              = "60"
  statistic           = "Minimum"
  threshold           = var.elk_free_storage_alarm_threshold
  alarm_description   = "OpenSearch free storage space is low"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DomainName = aws_opensearch_domain.elk.domain_name
    ClientId   = data.aws_caller_identity.current.account_id
  }

  tags = {
    Name = "${var.env}-opensearch-storage-alarm"
    Env  = var.env
  }
}

resource "aws_cloudwatch_metric_alarm" "opensearch_cpu_utilization" {
  alarm_name          = "${var.env}-opensearch-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "3"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ES"
  period              = "300"
  statistic           = "Average"
  threshold           = var.elk_cpu_alarm_threshold
  alarm_description   = "OpenSearch CPU utilization is high"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DomainName = aws_opensearch_domain.elk.domain_name
    ClientId   = data.aws_caller_identity.current.account_id
  }

  tags = {
    Name = "${var.env}-opensearch-cpu-alarm"
    Env  = var.env
  }
}

resource "aws_cloudwatch_metric_alarm" "opensearch_jvm_memory_pressure" {
  alarm_name          = "${var.env}-opensearch-high-jvm-memory"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "JVMMemoryPressure"
  namespace           = "AWS/ES"
  period              = "300"
  statistic           = "Maximum"
  threshold           = var.elk_jvm_memory_alarm_threshold
  alarm_description   = "OpenSearch JVM memory pressure is high"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DomainName = aws_opensearch_domain.elk.domain_name
    ClientId   = data.aws_caller_identity.current.account_id
  }

  tags = {
    Name = "${var.env}-opensearch-jvm-alarm"
    Env  = var.env
  }
}

# Data source for AWS account ID
data "aws_caller_identity" "current" {}
