locals {
  org = "azampay"
  env = var.env
}

module "eks" {
  source = "../../module"

  # Region and Environment
  aws-region = var.aws-region
  env        = var.env

  # VPC Configuration
  cidr-block = var.vpc-cidr-block
  vpc-name   = "${local.env}-${local.org}-${var.vpc-name}"
  igw-name   = "${local.env}-${local.org}-${var.igw-name}"
  eip-name   = "${local.env}-${local.org}-${var.eip-name}"
  ngw-name   = "${local.env}-${local.org}-${var.ngw-name}"
  eks-sg     = var.eks-sg

  # Public Subnet Configuration
  pub-subnet-count      = var.pub-subnet-count
  pub-cidr-block        = var.pub-cidr-block
  pub-availability-zone = var.pub-availability-zone
  pub-sub-name          = "${local.env}-${local.org}-${var.pub-sub-name}"
  public-rt-name        = "${local.env}-${local.org}-${var.public-rt-name}"

  # Private Subnet Configuration
  pri-subnet-count      = var.pri-subnet-count
  pri-cidr-block        = var.pri-cidr-block
  pri-availability-zone = var.pri-availability-zone
  pri-sub-name          = "${local.env}-${local.org}-${var.pri-sub-name}"
  private-rt-name       = "${local.env}-${local.org}-${var.private-rt-name}"

  # EKS Cluster Configuration
  cluster-name            = "${local.env}-${local.org}-${var.cluster-name}"
  is-eks-cluster-enabled  = var.is-eks-cluster-enabled
  cluster-version         = var.cluster-version
  endpoint-private-access = var.endpoint-private-access
  endpoint-public-access  = var.endpoint-public-access
  addons                  = var.addons

  # EKS IAM Configuration
  is_eks_role_enabled           = true
  is_eks_nodegroup_role_enabled = true

  # EKS Node Group Configuration
  ondemand_instance_types    = var.ondemand_instance_types
  desired_capacity_on_demand = var.desired_capacity_on_demand
  min_capacity_on_demand     = var.min_capacity_on_demand
  max_capacity_on_demand     = var.max_capacity_on_demand

  # Bastion Host Configuration
  bastion_allowed_cidr  = var.bastion_allowed_cidr
  bastion_ami_id        = var.bastion_ami_id
  bastion_instance_type = var.bastion_instance_type
  bastion_key_name      = var.bastion_key_name
  bastion_volume_size   = var.bastion_volume_size

  # MongoDB Configuration
  mongodb_ami_id        = var.mongodb_ami_id
  mongodb_instance_type = var.mongodb_instance_type
  mongodb_volume_size   = var.mongodb_volume_size

  # RDS Configuration
  rds_engine_version = var.rds_engine_version
  rds_instance_type  = var.rds_instance_type
  rds_storage_size   = var.rds_storage_size
  rds_database_name  = var.rds_database_name
  rds_username       = var.rds_username
  rds_password       = var.rds_password

  # Redis Configuration
  redis_engine_version             = var.redis_engine_version
  redis_node_type                  = var.redis_node_type
  redis_num_cache_nodes            = var.redis_num_cache_nodes
  redis_parameter_group_name       = var.redis_parameter_group_name
  redis_snapshot_retention_limit   = var.redis_snapshot_retention_limit
  redis_snapshot_window            = var.redis_snapshot_window
  redis_maintenance_window         = var.redis_maintenance_window
  redis_at_rest_encryption_enabled = var.redis_at_rest_encryption_enabled
  redis_transit_encryption_enabled = var.redis_transit_encryption_enabled

  # Kafka Configuration
  kafka_version                             = var.kafka_version
  kafka_instance_type                       = var.kafka_instance_type
  kafka_number_of_broker_nodes              = var.kafka_number_of_broker_nodes
  kafka_ebs_volume_size                     = var.kafka_ebs_volume_size
  kafka_log_retention_days                  = var.kafka_log_retention_days
  kafka_auto_create_topics                  = var.kafka_auto_create_topics
  kafka_default_replication_factor          = var.kafka_default_replication_factor
  kafka_min_insync_replicas                 = var.kafka_min_insync_replicas
  kafka_num_partitions                      = var.kafka_num_partitions
  kafka_encryption_in_transit_client_broker = var.kafka_encryption_in_transit_client_broker
  kafka_encryption_in_transit_in_cluster    = var.kafka_encryption_in_transit_in_cluster
  kafka_encryption_at_rest_kms_key_arn      = var.kafka_encryption_at_rest_kms_key_arn
  kafka_enhanced_monitoring                 = var.kafka_enhanced_monitoring

  # ELK (OpenSearch) Configuration
  elk_engine_version                 = var.elk_engine_version
  elk_instance_type                  = var.elk_instance_type
  elk_instance_count                 = var.elk_instance_count
  elk_zone_awareness_enabled         = var.elk_zone_awareness_enabled
  elk_availability_zone_count        = var.elk_availability_zone_count
  elk_dedicated_master_enabled       = var.elk_dedicated_master_enabled
  elk_dedicated_master_type          = var.elk_dedicated_master_type
  elk_dedicated_master_count         = var.elk_dedicated_master_count
  elk_warm_enabled                   = var.elk_warm_enabled
  elk_warm_count                     = var.elk_warm_count
  elk_warm_type                      = var.elk_warm_type
  elk_ebs_volume_size                = var.elk_ebs_volume_size
  elk_ebs_volume_type                = var.elk_ebs_volume_type
  elk_ebs_iops                       = var.elk_ebs_iops
  elk_ebs_throughput                 = var.elk_ebs_throughput
  elk_encrypt_at_rest                = var.elk_encrypt_at_rest
  elk_kms_key_id                     = var.elk_kms_key_id
  elk_node_to_node_encryption        = var.elk_node_to_node_encryption
  elk_advanced_security_enabled      = var.elk_advanced_security_enabled
  elk_internal_user_database_enabled = var.elk_internal_user_database_enabled
  elk_master_username                = var.elk_master_username
  elk_master_password                = var.elk_master_password
  elk_log_retention_days             = var.elk_log_retention_days
  elk_automated_snapshot_start_hour  = var.elk_automated_snapshot_start_hour
  elk_auto_tune_desired_state        = var.elk_auto_tune_desired_state
  elk_auto_tune_maintenance_start    = var.elk_auto_tune_maintenance_start
  elk_auto_tune_maintenance_duration = var.elk_auto_tune_maintenance_duration
  elk_auto_tune_cron_expression      = var.elk_auto_tune_cron_expression
  elk_create_service_linked_role     = var.elk_create_service_linked_role
  elk_free_storage_alarm_threshold   = var.elk_free_storage_alarm_threshold
  elk_cpu_alarm_threshold            = var.elk_cpu_alarm_threshold
  elk_jvm_memory_alarm_threshold     = var.elk_jvm_memory_alarm_threshold

  # ELK EC2 Configuration (Self-Managed)
  elk_ami_id                  = var.elk_ami_id
  elk_version                 = var.elk_version
  elk_data_node_count         = var.elk_data_node_count
  elk_kibana_instance_type    = var.elk_kibana_instance_type
  elk_heap_size_gb            = var.elk_heap_size_gb
  elk_snapshot_retention_days = var.elk_snapshot_retention_days
  elk_security_enabled        = var.elk_security_enabled
  elk_es_username             = var.elk_es_username
  elk_es_password             = var.elk_es_password
  elk_es_service_token        = var.elk_es_service_token

  # AWS Credentials
  aws_access_key_id     = var.aws_access_key_id
  aws_secret_access_key = var.aws_secret_access_key
}