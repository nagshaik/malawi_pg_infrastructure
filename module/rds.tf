resource "aws_security_group" "rds_sg" {
  name        = "${var.env}-rds-sg"
  description = "Security group for RDS MySQL instance"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]  # Allow access from bastion host
    description     = "Allow MySQL access from bastion"
  }

  # Allow access from EKS worker nodes (they use VPC CIDR)
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [var.cidr-block]
    description = "Allow MySQL access from EKS worker nodes in VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.env}-rds-sg"
    Env  = var.env
  }
}

# Allow access from AWS-managed EKS cluster security group
resource "aws_security_group_rule" "rds_from_eks_cluster_sg" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds_sg.id
  source_security_group_id = aws_eks_cluster.eks[0].vpc_config[0].cluster_security_group_id
  description              = "Allow MySQL access from AWS-managed EKS cluster security group"
}

resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "${var.env}-rds-subnet-group"
  subnet_ids = aws_subnet.private-subnet[*].id  # AWS requires at least 2 subnets in different AZs

  tags = {
    Name = "${var.env}-rds-subnet-group"
    Env  = var.env
  }
}

resource "aws_db_instance" "mysql" {
  identifier           = "${var.env}-mysql"
  engine              = "mysql"
  engine_version      = var.rds_engine_version
  instance_class      = var.rds_instance_type
  allocated_storage   = var.rds_storage_size
  storage_type        = "gp3"
  storage_encrypted   = true

  db_name             = var.rds_database_name
  username            = var.rds_username
  password            = var.rds_password

  multi_az                = true  # Enable Multi-AZ deployment for high availability
  availability_zone       = null  # Let AWS manage AZ placement for Multi-AZ
  db_subnet_group_name    = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids  = [aws_security_group.rds_sg.id]
  publicly_accessible     = false
  
  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "Mon:04:00-Mon:05:00"

  # Apply changes immediately instead of during maintenance window
  apply_immediately      = true
  
  # Allow storage to be modified
  max_allocated_storage  = 1000  # Enable storage autoscaling up to 1TB

  skip_final_snapshot    = true

  tags = {
    Name = "${var.env}-mysql"
    Env  = var.env
  }
}