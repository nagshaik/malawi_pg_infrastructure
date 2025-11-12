# ElastiCache Redis Subnet Group
resource "aws_elasticache_subnet_group" "redis" {
  name       = "${var.env}-redis-subnet-group"
  subnet_ids = aws_subnet.private-subnet[*].id

  tags = {
    Name = "${var.env}-redis-subnet-group"
    Env  = var.env
  }
}

# Security Group for Redis
resource "aws_security_group" "redis_sg" {
  name        = "${var.env}-redis-sg"
  description = "Security group for Redis ElastiCache cluster"
  vpc_id      = aws_vpc.vpc.id

  # Allow Redis traffic from VPC (includes EKS nodes and bastion)
  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = [var.cidr-block]
    description = "Allow Redis access from VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "${var.env}-redis-sg"
    Env  = var.env
  }
}

# Note: VPC CIDR ingress rule above already allows all EKS pods to access Redis
# No need for separate EKS cluster security group rule

# ElastiCache Redis Replication Group (Multi-AZ)
resource "aws_elasticache_replication_group" "redis" {
  replication_group_id = "${var.env}-redis-cluster"
  description          = "Multi-AZ Redis cluster for ${var.env}"
  
  engine               = "redis"
  engine_version       = var.redis_engine_version
  node_type            = var.redis_node_type
  num_cache_clusters   = var.redis_num_cache_nodes
  parameter_group_name = var.redis_parameter_group_name
  port                 = 6379
  
  # Multi-AZ Configuration
  automatic_failover_enabled = true
  multi_az_enabled          = true
  
  # Network Configuration
  subnet_group_name  = aws_elasticache_subnet_group.redis.name
  security_group_ids = [aws_security_group.redis_sg.id]
  
  # Backup Configuration
  snapshot_retention_limit = var.redis_snapshot_retention_limit
  snapshot_window          = var.redis_snapshot_window
  maintenance_window       = var.redis_maintenance_window
  
  # Encryption
  at_rest_encryption_enabled = var.redis_at_rest_encryption_enabled
  transit_encryption_enabled = var.redis_transit_encryption_enabled
  
  # Auto minor version upgrade
  auto_minor_version_upgrade = true
  
  # Notification topic (optional)
  # notification_topic_arn = var.redis_notification_topic_arn

  tags = {
    Name = "${var.env}-redis-cluster"
    Env  = var.env
  }
}
