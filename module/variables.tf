variable "cluster-name" {}
variable "cidr-block" {}
variable "vpc-name" {}
variable "env" {}
variable "igw-name" {}
variable "pub-subnet-count" {}
variable "pub-cidr-block" {
  type = list(string)
}
variable "pub-availability-zone" {
  type = list(string)
}
variable "pub-sub-name" {}
variable "pri-subnet-count" {}
variable "pri-cidr-block" {
  type = list(string)
}
variable "pri-availability-zone" {
  type = list(string)
}
variable "pri-sub-name" {}
variable "public-rt-name" {}
variable "private-rt-name" {}
variable "eip-name" {}
variable "ngw-name" {}
variable "eks-sg" {}


#IAM
variable "is_eks_role_enabled" {
  type = bool
}
variable "is_eks_nodegroup_role_enabled" {
  type = bool
}

# EKS
variable "is-eks-cluster-enabled" {}
variable "cluster-version" {}
variable "endpoint-private-access" {}
variable "endpoint-public-access" {}
variable "addons" {
  type = list(object({
    name    = string
    version = string
  }))
}
variable "ondemand_instance_types" {}
variable "desired_capacity_on_demand" {}
variable "min_capacity_on_demand" {}
variable "max_capacity_on_demand" {}

# AWS Region
variable "aws-region" {
  type        = string
  description = "AWS region for the resources"
}

# Optional: static AWS credentials to bootstrap the bastion's AWS CLI.
# Leave empty to rely on instance profile (recommended).
variable "aws_access_key_id" {
  type    = string
  default = ""
}

variable "aws_secret_access_key" {
  type    = string
  default = ""
}

# Bastion Host Variables
variable "bastion_allowed_cidr" {
  type        = list(string)
  description = "List of CIDR blocks allowed to connect to bastion host"
}

variable "bastion_ami_id" {
  type        = string
  description = "AMI ID for bastion host"
}

variable "bastion_instance_type" {
  type        = string
  description = "Instance type for bastion host"
  default     = "t3.micro"
}

variable "bastion_key_name" {
  type        = string
  description = "Name of the key pair to use for bastion host"
}

variable "bastion_volume_size" {
  type        = number
  description = "Size of the root volume for bastion host in GB"
  default     = 20
}

# MongoDB Variables
variable "mongodb_ami_id" {
  type        = string
  description = "AMI ID for MongoDB instance"
}

variable "mongodb_instance_type" {
  type        = string
  description = "Instance type for MongoDB instance"
  default     = "t3.medium"
}

variable "mongodb_volume_size" {
  type        = number
  description = "Size of the root volume for MongoDB instance in GB"
  default     = 30
}

# RDS Variables
variable "rds_engine_version" {
  type        = string
  description = "MySQL engine version"
  default     = "8.0.42"
}

variable "rds_instance_type" {
  type        = string
  description = "RDS instance type"
  default     = "db.m5.large"
}

variable "rds_storage_size" {
  type        = number
  description = "Size of RDS storage in GB"
  default     = 300
}

variable "rds_database_name" {
  type        = string
  description = "Name of the initial database"
}

variable "rds_username" {
  type        = string
  description = "Master username for RDS instance"
}

variable "rds_password" {
  type        = string
  description = "Master password for RDS instance"
  sensitive   = true
}

# Redis Variables
variable "redis_engine_version" {
  type        = string
  description = "Redis engine version"
  default     = "7.1"
}

variable "redis_node_type" {
  type        = string
  description = "Redis node instance type"
  default     = "cache.t3.medium"
}

variable "redis_num_cache_nodes" {
  type        = number
  description = "Number of cache nodes in the Redis cluster (minimum 2 for Multi-AZ)"
  default     = 2
}

variable "redis_parameter_group_name" {
  type        = string
  description = "Redis parameter group name"
  default     = "default.redis7"
}

variable "redis_snapshot_retention_limit" {
  type        = number
  description = "Number of days to retain Redis snapshots"
  default     = 5
}

variable "redis_snapshot_window" {
  type        = string
  description = "Daily time range for Redis snapshots (UTC)"
  default     = "03:00-05:00"
}

variable "redis_maintenance_window" {
  type        = string
  description = "Weekly time range for Redis maintenance (UTC)"
  default     = "sun:05:00-sun:07:00"
}

variable "redis_at_rest_encryption_enabled" {
  type        = bool
  description = "Enable encryption at rest for Redis"
  default     = false
}

variable "redis_transit_encryption_enabled" {
  type        = bool
  description = "Enable encryption in transit for Redis"
  default     = false
}

# Kafka MSK Variables
variable "kafka_version" {
  type        = string
  description = "Kafka version for MSK cluster"
  default     = "3.5.1"
}

variable "kafka_instance_type" {
  type        = string
  description = "Instance type for Kafka brokers"
  default     = "kafka.m5.large"
}

variable "kafka_number_of_broker_nodes" {
  type        = number
  description = "Number of broker nodes in Kafka cluster (must be multiple of AZs)"
  default     = 2
}

variable "kafka_ebs_volume_size" {
  type        = number
  description = "EBS volume size for each Kafka broker (GB)"
  default     = 100
}

variable "kafka_log_retention_days" {
  type        = number
  description = "CloudWatch log retention for Kafka logs (days)"
  default     = 7
}

variable "kafka_auto_create_topics" {
  type        = bool
  description = "Enable auto creation of topics"
  default     = true
}

variable "kafka_default_replication_factor" {
  type        = number
  description = "Default replication factor for topics"
  default     = 2
}

variable "kafka_min_insync_replicas" {
  type        = number
  description = "Minimum in-sync replicas for topics"
  default     = 1
}

variable "kafka_num_partitions" {
  type        = number
  description = "Default number of partitions for topics"
  default     = 3
}

variable "kafka_encryption_in_transit_client_broker" {
  type        = string
  description = "Encryption in transit between clients and brokers: TLS, TLS_PLAINTEXT, PLAINTEXT"
  default     = "TLS"
}

variable "kafka_encryption_in_transit_in_cluster" {
  type        = bool
  description = "Enable encryption in transit within cluster"
  default     = true
}

variable "kafka_encryption_at_rest_kms_key_arn" {
  type        = string
  description = "KMS key ARN for encryption at rest (leave empty for AWS managed key)"
  default     = ""
}

variable "kafka_enhanced_monitoring" {
  type        = string
  description = "Enhanced monitoring level: DEFAULT, PER_BROKER, PER_TOPIC_PER_BROKER, PER_TOPIC_PER_PARTITION"
  default     = "DEFAULT"
}
