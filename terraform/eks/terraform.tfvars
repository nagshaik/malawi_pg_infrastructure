env                   = "malawi-pg"
aws-region            = "eu-central-1"
vpc-cidr-block        = "10.16.0.0/16"
vpc-name              = "vpc"
igw-name              = "igw"
pub-subnet-count      = 2
pub-cidr-block        = ["10.16.0.0/20", "10.16.16.0/20"]
pub-availability-zone = ["eu-central-1a", "eu-central-1b"]
pub-sub-name          = "subnet-public"
pri-subnet-count      = 2
pri-cidr-block        = ["10.16.128.0/20", "10.16.144.0/20", ]
pri-availability-zone = ["eu-central-1a", "eu-central-1b"]
pri-sub-name          = "subnet-private"
public-rt-name        = "public-route-table"
private-rt-name       = "private-route-table"
eip-name              = "elasticip-ngw"
ngw-name              = "ngw"
eks-sg                = "eks-sg"

# EKS
is-eks-cluster-enabled     = true
cluster-version            = "1.34"
cluster-name               = "malawi-pg-eks"
endpoint-private-access    = true
endpoint-public-access     = true
ondemand_instance_types    = ["m5.large"]
desired_capacity_on_demand = "2"
min_capacity_on_demand     = "2"
max_capacity_on_demand     = "3"
addons = [
  {
    name    = "vpc-cni"
    version = "v1.20.0-eksbuild.1"
  },
  {
    name    = "coredns"
    version = "v1.12.2-eksbuild.4"
  },
  {
    name    = "kube-proxy"
    version = "v1.34.0-eksbuild.2"
  },
  {
    name    = "aws-ebs-csi-driver"
    version = "v1.46.0-eksbuild.1"
  }
]

bastion_allowed_cidr  = ["0.0.0.0/0"]
bastion_ami_id        = "ami-0a116fa7c861dd5f9"
bastion_instance_type = "m5.xlarge"
bastion_key_name      = "kenya-pg-key"
bastion_volume_size   = 50

mongodb_ami_id        = "ami-0a116fa7c861dd5f9"
mongodb_instance_type = "m6i.large"
mongodb_volume_size   = 500

rds_engine_version = "8.0.42"
rds_instance_type  = "db.m5.large"
rds_storage_size   = 300
rds_database_name  = "malawi_pg_db"
rds_username       = "admin"
rds_password       = "MalawiPG2025!#"

redis_engine_version             = "7.1"
redis_node_type                  = "cache.t3.medium"
redis_num_cache_nodes            = 2
redis_parameter_group_name       = "default.redis7"
redis_snapshot_retention_limit   = 5
redis_snapshot_window            = "03:00-05:00"
redis_maintenance_window         = "sun:05:00-sun:07:00"
redis_at_rest_encryption_enabled = false
redis_transit_encryption_enabled = false

kafka_version                             = "3.5.1"
kafka_instance_type                       = "kafka.m5.large"
kafka_number_of_broker_nodes              = 2
kafka_ebs_volume_size                     = 100
kafka_log_retention_days                  = 7
kafka_auto_create_topics                  = true
kafka_default_replication_factor          = 2
kafka_min_insync_replicas                 = 1
kafka_num_partitions                      = 3
kafka_encryption_in_transit_client_broker = "TLS"
kafka_encryption_in_transit_in_cluster    = true
kafka_encryption_at_rest_kms_key_arn      = ""
kafka_enhanced_monitoring                 = "DEFAULT"

elk_ami_id                  = "ami-0a116fa7c861dd5f9"
elk_version                 = "8.11.3"
elk_data_node_count         = 1
elk_instance_type           = "r6i.large"
elk_kibana_instance_type    = "t3.large"
elk_heap_size_gb            = 8
elk_ebs_volume_size         = 250
elk_ebs_volume_type         = "gp3"
elk_ebs_iops                = 3000
elk_ebs_throughput          = 125
elk_snapshot_retention_days = 30
elk_master_username         = "admin"
elk_master_password         = "MalawiELK2025!Secure#"
elk_log_retention_days      = 30
elk_cpu_alarm_threshold     = 80
elk_security_enabled        = true
elk_es_username             = "elastic"
elk_es_password             = "PHQ3-8l4ac8AhtTAOVFi"
elk_es_service_token        = "AAEAAWVsYXN0aWMva2liYW5hL2tpYmFuYS10b2tlbjp0ak9YeHpEdVFCLXFHRVhBWWh5Tzdn"

argocd_username = "admin"
argocd_password = "EjwUqkAM4VpfRiA6"
argocd_url      = "http://a97086c1c1fa245558968ea3952ec3ae-248736526.eu-central-1.elb.amazonaws.com"

aws_access_key_id     = ""
aws_secret_access_key = ""
