# Security Group for Kafka MSK
resource "aws_security_group" "kafka_sg" {
  name        = "${var.env}-kafka-sg"
  description = "Security group for Kafka MSK cluster"
  vpc_id      = aws_vpc.vpc.id

  # Kafka plaintext communication
  ingress {
    from_port   = 9092
    to_port     = 9092
    protocol    = "tcp"
    cidr_blocks = [var.cidr-block]
    description = "Allow Kafka plaintext from VPC"
  }

  # Kafka TLS communication
  ingress {
    from_port   = 9094
    to_port     = 9094
    protocol    = "tcp"
    cidr_blocks = [var.cidr-block]
    description = "Allow Kafka TLS from VPC"
  }

  # Kafka SASL/SCRAM communication
  ingress {
    from_port   = 9096
    to_port     = 9096
    protocol    = "tcp"
    cidr_blocks = [var.cidr-block]
    description = "Allow Kafka SASL/SCRAM from VPC"
  }

  # Zookeeper
  ingress {
    from_port   = 2181
    to_port     = 2181
    protocol    = "tcp"
    cidr_blocks = [var.cidr-block]
    description = "Allow Zookeeper from VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "${var.env}-kafka-sg"
    Env  = var.env
  }
}

# Explicit rule to allow AWS-managed EKS cluster security group for SASL/SCRAM
resource "aws_security_group_rule" "kafka_from_eks_cluster_sg" {
  count                    = var.is-eks-cluster-enabled ? 1 : 0
  type                     = "ingress"
  from_port                = 9096
  to_port                  = 9096
  protocol                 = "tcp"
  security_group_id        = aws_security_group.kafka_sg.id
  source_security_group_id = aws_eks_cluster.eks[0].vpc_config[0].cluster_security_group_id
  description              = "Allow Kafka SASL/SCRAM access from AWS-managed EKS cluster security group"
}

# CloudWatch Log Group for Kafka
resource "aws_cloudwatch_log_group" "kafka_log_group" {
  name              = "/aws/msk/${var.env}-kafka-cluster"
  retention_in_days = var.kafka_log_retention_days

  tags = {
    Name = "${var.env}-kafka-logs"
    Env  = var.env
  }
}

# MSK Configuration
resource "aws_msk_configuration" "kafka_config" {
  name              = "${var.env}-kafka-configuration"
  kafka_versions    = [var.kafka_version]
  server_properties = <<PROPERTIES
auto.create.topics.enable = ${var.kafka_auto_create_topics}
default.replication.factor = ${var.kafka_default_replication_factor}
min.insync.replicas = ${var.kafka_min_insync_replicas}
num.io.threads = 8
num.network.threads = 5
num.partitions = ${var.kafka_num_partitions}
num.replica.fetchers = 2
replica.lag.time.max.ms = 30000
socket.receive.buffer.bytes = 102400
socket.request.max.bytes = 104857600
socket.send.buffer.bytes = 102400
unclean.leader.election.enable = false
zookeeper.session.timeout.ms = 18000
PROPERTIES

  description = "MSK configuration for ${var.env} environment"
}

# MSK Cluster
resource "aws_msk_cluster" "kafka" {
  cluster_name           = "${var.env}-kafka-cluster"
  kafka_version          = var.kafka_version
  number_of_broker_nodes = var.kafka_number_of_broker_nodes

  broker_node_group_info {
    instance_type   = var.kafka_instance_type
    client_subnets  = aws_subnet.private-subnet[*].id
    security_groups = [aws_security_group.kafka_sg.id]

    storage_info {
      ebs_storage_info {
        volume_size = var.kafka_ebs_volume_size
      }
    }
  }

  configuration_info {
    arn      = aws_msk_configuration.kafka_config.arn
    revision = aws_msk_configuration.kafka_config.latest_revision
  }

  # Enable user-based auth with SASL/SCRAM
  client_authentication {
    sasl {
      scram = true
    }
  }

  encryption_info {
    encryption_in_transit {
      client_broker = var.kafka_encryption_in_transit_client_broker
      in_cluster    = var.kafka_encryption_in_transit_in_cluster
    }

    encryption_at_rest_kms_key_arn = var.kafka_encryption_at_rest_kms_key_arn
  }

  enhanced_monitoring = var.kafka_enhanced_monitoring

  logging_info {
    broker_logs {
      cloudwatch_logs {
        enabled   = true
        log_group = aws_cloudwatch_log_group.kafka_log_group.name
      }
    }
  }

  tags = {
    Name = "${var.env}-kafka-cluster"
    Env  = var.env
  }
}

# KMS key for encrypting Kafka SCRAM secrets (required by MSK)
resource "aws_kms_key" "kafka_scram" {
  description             = "KMS key for Kafka SCRAM secrets"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow Kafka to use the key"
        Effect = "Allow"
        Principal = {
          Service = "kafka.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name = "${var.env}-kafka-scram-kms"
    Env  = var.env
  }
}

resource "aws_kms_alias" "kafka_scram" {
  name          = "alias/${var.env}-kafka-scram"
  target_key_id = aws_kms_key.kafka_scram.key_id
}

# Secret for Kafka SASL/SCRAM user credentials (username: client)
resource "aws_secretsmanager_secret" "kafka_scram_client" {
  name        = "AmazonMSK_client"
  description = "SCRAM credentials for Kafka user 'client'"
  kms_key_id  = aws_kms_key.kafka_scram.arn

  tags = {
    AWSKafkaSecret = "true"
    Env            = var.env
  }
}

resource "aws_secretsmanager_secret_version" "kafka_scram_client" {
  secret_id     = aws_secretsmanager_secret.kafka_scram_client.id
  secret_string = jsonencode({ username = "client", password = "azamPg_pass20" })
}

# Allow MSK service to read the secret
resource "aws_secretsmanager_secret_policy" "kafka_scram_client" {
  secret_arn = aws_secretsmanager_secret.kafka_scram_client.arn
  policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Sid       = "AllowKafkaToUseSecret",
        Effect    = "Allow",
        Principal = { Service = "kafka.amazonaws.com" },
        Action    = [
          "secretsmanager:DescribeSecret",
          "secretsmanager:GetSecretValue",
          "secretsmanager:ListSecretVersionIds"
        ],
        Resource = aws_secretsmanager_secret.kafka_scram_client.arn
      }
    ]
  })
}

# Associate the SCRAM secret with MSK cluster
resource "aws_msk_scram_secret_association" "kafka_scram" {
  cluster_arn     = aws_msk_cluster.kafka.arn
  secret_arn_list = [aws_secretsmanager_secret.kafka_scram_client.arn]

  depends_on = [
    aws_secretsmanager_secret_version.kafka_scram_client,
    aws_secretsmanager_secret_policy.kafka_scram_client
  ]
}
