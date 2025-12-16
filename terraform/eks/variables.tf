variable "aws-region" {}
variable "aws_account_id" { }
variable "env" {}
variable "cluster-name" {}
variable "vpc-cidr-block" {}
variable "vpc-name" {}
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



# EKS
variable "is-eks-cluster-enabled" {}
variable "cluster-version" {}
variable "endpoint-private-access" {}
variable "endpoint-public-access" {}
variable "ondemand_instance_types" {
  default = ["t3a.medium"]
}


variable "desired_capacity_on_demand" {}
variable "min_capacity_on_demand" {}
variable "max_capacity_on_demand" {}
variable "addons" {
  type = list(object({
    name    = string
    version = string
  }))
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

# AWS Credentials (optional)
variable "aws_access_key_id" {
  type        = string
  description = "AWS Access Key ID"
  default     = ""
  sensitive   = true
}

variable "aws_secret_access_key" {
  type        = string
  description = "AWS Secret Access Key"
  default     = ""
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

# ELK (OpenSearch) Variables
variable "elk_engine_version" {
  type        = string
  description = "OpenSearch engine version"
  default     = "OpenSearch_2.11"
}

variable "elk_instance_type" {
  type        = string
  description = "Instance type for OpenSearch data nodes"
  default     = "r7g.medium.search"
}

variable "elk_instance_count" {
  type        = number
  description = "Number of instances in the OpenSearch cluster"
  default     = 2
}

variable "elk_zone_awareness_enabled" {
  type        = bool
  description = "Enable zone awareness for OpenSearch cluster (Multi-AZ)"
  default     = true
}

variable "elk_availability_zone_count" {
  type        = number
  description = "Number of availability zones for the OpenSearch cluster"
  default     = 2
}

variable "elk_dedicated_master_enabled" {
  type        = bool
  description = "Enable dedicated master nodes for OpenSearch cluster"
  default     = true
}

variable "elk_dedicated_master_type" {
  type        = string
  description = "Instance type for OpenSearch dedicated master nodes"
  default     = "r7g.medium.search"
}

variable "elk_dedicated_master_count" {
  type        = number
  description = "Number of dedicated master nodes"
  default     = 3
}

variable "elk_warm_enabled" {
  type        = bool
  description = "Enable warm storage for OpenSearch (UltraWarm)"
  default     = false
}

variable "elk_warm_count" {
  type        = number
  description = "Number of warm nodes"
  default     = 2
}

variable "elk_warm_type" {
  type        = string
  description = "Instance type for warm nodes"
  default     = "ultrawarm1.medium.search"
}

variable "elk_ebs_enabled" {
  type        = bool
  description = "Enable EBS volumes for OpenSearch nodes"
  default     = true
}

variable "elk_ebs_volume_size" {
  type        = number
  description = "Size of EBS volume for each OpenSearch node (GB)"
  default     = 100
}

variable "elk_ebs_volume_type" {
  type        = string
  description = "Type of EBS volume (gp2, gp3, io1)"
  default     = "gp3"
}

variable "elk_ebs_iops" {
  type        = number
  description = "IOPS for EBS volume (for gp3 or io1)"
  default     = 3000
}

variable "elk_ebs_throughput" {
  type        = number
  description = "Throughput for EBS volume in MB/s (for gp3 only)"
  default     = 125
}

variable "elk_encrypt_at_rest" {
  type        = bool
  description = "Enable encryption at rest for OpenSearch"
  default     = true
}

variable "elk_kms_key_id" {
  type        = string
  description = "KMS key ID for encryption (empty for AWS managed key)"
  default     = ""
}

variable "elk_node_to_node_encryption" {
  type        = bool
  description = "Enable node-to-node encryption for OpenSearch"
  default     = true
}

variable "elk_advanced_security_enabled" {
  type        = bool
  description = "Enable fine-grained access control for OpenSearch"
  default     = true
}

variable "elk_internal_user_database_enabled" {
  type        = bool
  description = "Enable internal user database for fine-grained access control"
  default     = true
}

variable "elk_master_username" {
  type        = string
  description = "Master username for OpenSearch fine-grained access control"
  default     = "admin"
}

variable "elk_master_password" {
  type        = string
  description = "Master password for OpenSearch fine-grained access control (min 8 chars)"
  sensitive   = true
}

variable "elk_log_retention_days" {
  type        = number
  description = "CloudWatch log retention period in days"
  default     = 30
}

variable "elk_automated_snapshot_start_hour" {
  type        = number
  description = "Hour to start automated snapshots (UTC, 0-23)"
  default     = 3
}

variable "elk_auto_tune_desired_state" {
  type        = string
  description = "Auto-Tune desired state: ENABLED or DISABLED"
  default     = "ENABLED"
}

variable "elk_auto_tune_maintenance_start" {
  type        = string
  description = "Auto-Tune maintenance start time (RFC3339 format)"
  default     = "2025-11-06T00:00:00Z"
}

variable "elk_auto_tune_maintenance_duration" {
  type        = number
  description = "Auto-Tune maintenance window duration (hours)"
  default     = 2
}

variable "elk_auto_tune_cron_expression" {
  type        = string
  description = "Cron expression for Auto-Tune maintenance schedule"
  default     = "cron(0 3 ? * SUN *)"
}

variable "elk_create_service_linked_role" {
  type        = bool
  description = "Create IAM service-linked role for OpenSearch (set to false if already exists)"
  default     = false
}

variable "elk_free_storage_alarm_threshold" {
  type        = number
  description = "Free storage space alarm threshold (MB)"
  default     = 10000
}

variable "elk_cpu_alarm_threshold" {
  type        = number
  description = "CPU utilization alarm threshold (percentage)"
  default     = 80
}

# Security settings for Elasticsearch/Kibana
variable "elk_security_enabled" {
  type        = bool
  description = "Enable Elasticsearch security (TLS + auth) and configure Kibana to use HTTPS"
  default     = true
}

variable "elk_es_username" {
  type        = string
  description = "Username Kibana uses to authenticate to Elasticsearch when security is enabled"
  default     = "elastic"
}

variable "elk_es_password" {
  type        = string
  sensitive   = true
  description = "Password Kibana uses to authenticate to Elasticsearch when security is enabled"
  default     = ""
}

variable "elk_es_service_token" {
  type        = string
  sensitive   = true
  description = "Elasticsearch service account token for Kibana (preferred over username/password)"
  default     = ""
}

variable "elk_jvm_memory_alarm_threshold" {
  type        = number
  description = "JVM memory pressure alarm threshold (percentage)"
  default     = 85
}

# ELK EC2 Variables (Self-Managed)
variable "elk_ami_id" {
  type        = string
  description = "AMI ID for ELK instances (Ubuntu)"
  default     = ""
}

variable "elk_version" {
  type        = string
  description = "Elasticsearch/Kibana version"
  default     = "8.11.3"
}

variable "elk_data_node_count" {
  type        = number
  description = "Number of Elasticsearch data nodes"
  default     = 2
}

variable "elk_kibana_instance_type" {
  type        = string
  description = "Instance type for Kibana"
  default     = "t3.large"
}

variable "elk_heap_size_gb" {
  type        = number
  description = "Elasticsearch JVM heap size in GB"
  default     = 8
}

variable "elk_snapshot_retention_days" {
  type        = number
  description = "Number of days to retain snapshots in S3"
  default     = 30
}

