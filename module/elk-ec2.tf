# Self-Managed ELK Stack on EC2 with Ubuntu (Elasticsearch + Kibana)
# Kibana is publicly accessible with basic auth

# Security Group for ELK Cluster
resource "aws_security_group" "elk_sg" {
  name        = "${var.env}-elk-sg"
  description = "Security group for self-managed ELK cluster"
  vpc_id      = aws_vpc.vpc.id

  # Elasticsearch API (9200) - for Fluent Bit from VPC
  ingress {
    from_port   = 9200
    to_port     = 9200
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.vpc.cidr_block]
    description = "Elasticsearch API access from VPC"
  }

  # Elasticsearch transport (9300) - for cluster communication
  ingress {
    from_port = 9300
    to_port   = 9300
    protocol  = "tcp"
    self      = true
    description = "Elasticsearch cluster transport"
  }

  # SSH from bastion
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
    description     = "SSH access from bastion"
  }

  # SSH between Elasticsearch nodes (for cluster management)
  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
    self      = true
    description = "SSH between Elasticsearch nodes"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "${var.env}-elk-sg"
    Env  = var.env
  }
}

# Security Group for Kibana (Public Access)
resource "aws_security_group" "kibana_sg" {
  name        = "${var.env}-kibana-sg"
  description = "Security group for Kibana with public access"
  vpc_id      = aws_vpc.vpc.id

  # HTTP access from anywhere (protected by basic auth)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP access for Kibana (basic auth protected)"
  }

  # HTTPS access from anywhere (optional)
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS access for Kibana"
  }

  # Kibana internal port (5601) - access to Elasticsearch nodes
  egress {
    from_port       = 9200
    to_port         = 9200
    protocol        = "tcp"
    security_groups = [aws_security_group.elk_sg.id]
    description     = "Access to Elasticsearch cluster"
  }

  # SSH from bastion
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
    description     = "SSH access from bastion"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "${var.env}-kibana-sg"
    Env  = var.env
  }
}

# IAM Role for ELK EC2 Instances
resource "aws_iam_role" "elk_role" {
  name = "${var.env}-elk-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.env}-elk-role"
    Env  = var.env
  }
}

# IAM Policy for ELK instances
resource "aws_iam_role_policy" "elk_policy" {
  name = "${var.env}-elk-policy"
  role = aws_iam_role.elk_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeTags",
          "cloudwatch:PutMetricData",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:PutParameter",
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach SSM policy for easy instance management
resource "aws_iam_role_policy_attachment" "elk_ssm" {
  role       = aws_iam_role.elk_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Instance Profile
resource "aws_iam_instance_profile" "elk_profile" {
  name = "${var.env}-elk-profile"
  role = aws_iam_role.elk_role.name

  tags = {
    Name = "${var.env}-elk-profile"
    Env  = var.env
  }
}

# S3 Bucket for ELK Snapshots/Backups
resource "aws_s3_bucket" "elk_snapshots" {
  bucket = "${var.env}-elk-snapshots-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name = "${var.env}-elk-snapshots"
    Env  = var.env
  }
}

resource "aws_s3_bucket_versioning" "elk_snapshots" {
  bucket = aws_s3_bucket.elk_snapshots.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "elk_snapshots" {
  bucket = aws_s3_bucket.elk_snapshots.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "elk_snapshots" {
  bucket = aws_s3_bucket.elk_snapshots.id

  rule {
    id     = "expire-old-snapshots"
    status = "Enabled"

    expiration {
      days = var.elk_snapshot_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }
}

# EBS Volumes for Elasticsearch Data
resource "aws_ebs_volume" "elk_data" {
  count             = var.elk_data_node_count
  availability_zone = element(var.pri-availability-zone, count.index % length(var.pri-availability-zone))
  size              = var.elk_ebs_volume_size
  type              = var.elk_ebs_volume_type
  iops              = var.elk_ebs_volume_type == "gp3" || var.elk_ebs_volume_type == "io1" ? var.elk_ebs_iops : null
  throughput        = var.elk_ebs_volume_type == "gp3" ? var.elk_ebs_throughput : null
  encrypted         = true

  tags = {
    Name = "${var.env}-elk-data-${count.index + 1}"
    Env  = var.env
    Type = "elasticsearch-data"
  }
}

# User Data Script for Elasticsearch Data Nodes (Ubuntu)
locals {
  elasticsearch_user_data = <<-EOF
    #!/bin/bash
    set -e
    
    # Update system
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get upgrade -y
    
    # Install required packages
    apt-get install -y wget apt-transport-https gnupg2 curl
    
    # Install Java 17
    apt-get install -y openjdk-17-jdk
    
    # Import Elasticsearch GPG key
    wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | gpg --dearmor -o /usr/share/keyrings/elasticsearch-keyring.gpg
    
    # Add Elasticsearch repository
    echo "deb [signed-by=/usr/share/keyrings/elasticsearch-keyring.gpg] https://artifacts.elastic.co/packages/8.x/apt stable main" | tee /etc/apt/sources.list.d/elastic-8.x.list
    
    # Install Elasticsearch
    apt-get update
    apt-get install -y elasticsearch=${var.elk_version}
    
    # Wait for data volume
    sleep 10
    
    # Mount data volume
    DATA_DEVICE=$(lsblk -d -n -o NAME,TYPE | grep disk | tail -n1 | awk '{print "/dev/"$1}')
    mkfs -t ext4 $DATA_DEVICE || true
    mkdir -p /var/lib/elasticsearch
    echo "$DATA_DEVICE /var/lib/elasticsearch ext4 defaults,nofail 0 2" >> /etc/fstab
    mount -a
    chown -R elasticsearch:elasticsearch /var/lib/elasticsearch
    
    # Get instance metadata
    INSTANCE_ID=$(ec2-metadata --instance-id | cut -d " " -f 2)
    PRIVATE_IP=$(ec2-metadata --local-ipv4 | cut -d " " -f 2)
    
    # Configure Elasticsearch
    cat > /etc/elasticsearch/elasticsearch.yml <<CONFIG
    cluster.name: ${var.env}-elk-cluster
    node.name: $INSTANCE_ID
    node.roles: [ data, master ]
    path.data: /var/lib/elasticsearch
    path.logs: /var/log/elasticsearch
    network.host: $PRIVATE_IP
    http.port: 9200
    
    # Single-node mode removes need for seed hosts and initial master nodes
    discovery.type: single-node
    ${var.elk_security_enabled ? "" : "xpack.security.enabled: false\n    xpack.security.enrollment.enabled: false\n    xpack.security.http.ssl.enabled: false\n    xpack.security.transport.ssl.enabled: false"}
    
    # Performance settings
    bootstrap.memory_lock: true
    indices.memory.index_buffer_size: 30%
    indices.lifecycle.poll_interval: 10m
    CONFIG
    
    # Set JVM heap
    HEAP_SIZE="${var.elk_heap_size_gb}g"
    cat > /etc/elasticsearch/jvm.options.d/heap.options <<HEAP
    -Xms$HEAP_SIZE
    -Xmx$HEAP_SIZE
    HEAP
    
    # Enable memory lock
    mkdir -p /etc/systemd/system/elasticsearch.service.d
    cat > /etc/systemd/system/elasticsearch.service.d/override.conf <<OVERRIDE
    [Service]
    LimitMEMLOCK=infinity
    OVERRIDE
    
    # Start Elasticsearch
    systemctl daemon-reload
    systemctl enable elasticsearch
    systemctl start elasticsearch
    
    # Wait for startup
    sleep 30
    
    # Install CloudWatch agent
    wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
    dpkg -i -E ./amazon-cloudwatch-agent.deb
    
    # Configure CloudWatch agent
    cat > /opt/aws/amazon-cloudwatch-agent/etc/config.json <<CW
    {
      "logs": {
        "logs_collected": {
          "files": {
            "collect_list": [
              {
                "file_path": "/var/log/elasticsearch/*.log",
                "log_group_name": "/aws/ec2/elk/${var.env}",
                "log_stream_name": "{instance_id}/elasticsearch"
              }
            ]
          }
        }
      },
      "metrics": {
        "namespace": "ELK/EC2",
        "metrics_collected": {
          "disk": {
            "measurement": [
              {
                "name": "used_percent",
                "rename": "DiskUsedPercent",
                "unit": "Percent"
              }
            ],
            "metrics_collection_interval": 60,
            "resources": ["/var/lib/elasticsearch"]
          },
          "mem": {
            "measurement": [
              {
                "name": "mem_used_percent",
                "rename": "MemoryUsedPercent",
                "unit": "Percent"
              }
            ],
            "metrics_collection_interval": 60
          }
        }
      }
    }
    CW
    
    /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
      -a fetch-config -m ec2 -s -c file:/opt/aws/amazon-cloudwatch-agent/etc/config.json
    
    echo "Elasticsearch node setup complete"
  EOF

  kibana_user_data = <<-EOF
    #!/bin/bash
    set -e
    
    # Update system
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get upgrade -y
    
    # Install required packages
    apt-get install -y wget apt-transport-https gnupg2 curl nginx apache2-utils openjdk-17-jdk
    
    # Import Elasticsearch GPG key
    wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | gpg --dearmor -o /usr/share/keyrings/elasticsearch-keyring.gpg
    
    # Add Elastic repository
    echo "deb [signed-by=/usr/share/keyrings/elasticsearch-keyring.gpg] https://artifacts.elastic.co/packages/8.x/apt stable main" | tee /etc/apt/sources.list.d/elastic-8.x.list
    
    # Install Kibana
    apt-get update
    apt-get install -y kibana=${var.elk_version}
    
    # Wait for Elasticsearch
    sleep 60
    
    # Configure Kibana
    cat > /etc/kibana/kibana.yml <<CONFIG
    server.port: 5601
    server.host: "0.0.0.0"
    server.name: "${var.env}-kibana"
    server.publicBaseUrl: "http://${aws_eip.kibana.public_ip}"
    
    elasticsearch.hosts: ["${var.elk_security_enabled ? "https" : "http"}://10.16.128.10:9200"]
    ${var.elk_security_enabled ? (var.elk_es_service_token != "" ? "elasticsearch.serviceAccountToken: \"${var.elk_es_service_token}\"\nelasticsearch.ssl.verificationMode: none" : "elasticsearch.username: \"${var.elk_es_username}\"\nelasticsearch.password: \"${var.elk_es_password}\"\nelasticsearch.ssl.verificationMode: none") : ""}
    
    logging.appenders.file.type: file
    logging.appenders.file.fileName: /var/log/kibana/kibana.log
    logging.appenders.file.layout.type: json
    
    xpack.encryptedSavedObjects.encryptionKey: "${random_password.kibana_encryption_key.result}"
    xpack.reporting.encryptionKey: "${random_password.kibana_reporting_key.result}"
    xpack.security.encryptionKey: "${random_password.kibana_security_key.result}"
    
    xpack.security.enabled: ${var.elk_security_enabled}
    CONFIG
    
    # Start Kibana
    systemctl enable kibana
    systemctl start kibana
    
    # Configure basic auth
    htpasswd -bc /etc/nginx/.htpasswd ${var.elk_master_username} '${var.elk_master_password}'
    
    # Configure nginx reverse proxy with rate limiting
    cat > /etc/nginx/sites-available/kibana <<'NGINX'
    limit_req_zone $binary_remote_addr zone=kibana_limit:10m rate=10r/s;
    
    server {
        listen 80;
        server_name _;
        
        # Basic authentication
        auth_basic "Kibana Access";
        auth_basic_user_file /etc/nginx/.htpasswd;
        
        # Rate limiting
        limit_req zone=kibana_limit burst=20 nodelay;
        
        location / {
            proxy_pass http://localhost:5601;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host $host;
            proxy_cache_bypass $http_upgrade;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            
            # Timeouts
            proxy_connect_timeout 600;
            proxy_send_timeout 600;
            proxy_read_timeout 600;
        }
    }
    NGINX
    
    # Enable site
    rm -f /etc/nginx/sites-enabled/default
    ln -s /etc/nginx/sites-available/kibana /etc/nginx/sites-enabled/
    
    # Test and restart nginx
    nginx -t
    systemctl enable nginx
    systemctl restart nginx
    
    echo "Kibana setup complete - accessible at http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
  EOF
}

# Random keys for Kibana encryption
resource "random_password" "kibana_encryption_key" {
  length  = 32
  special = false
}

resource "random_password" "kibana_reporting_key" {
  length  = 32
  special = false
}

resource "random_password" "kibana_security_key" {
  length  = 32
  special = false
}

# Elasticsearch Data Nodes (Private Subnet)
resource "aws_instance" "elasticsearch" {
  count                  = var.elk_data_node_count
  ami                    = var.elk_ami_id
  instance_type          = var.elk_instance_type
  subnet_id              = element(aws_subnet.private-subnet[*].id, count.index % length(aws_subnet.private-subnet))
  vpc_security_group_ids = [aws_security_group.elk_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.elk_profile.name
  key_name               = var.bastion_key_name

  # Assign IPs based on actual subnet: 10.16.128.10 (AZ a), 10.16.144.10 (AZ b)
  private_ip = count.index == 0 ? "10.16.128.10" : "10.16.144.10"

  user_data = local.elasticsearch_user_data

  root_block_device {
    volume_size = 50
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name = "${var.env}-elasticsearch-${count.index + 1}"
    Env  = var.env
    Role = "elasticsearch-data"
  }

  lifecycle {
    ignore_changes = [ami]
  }
}

# Attach data volumes to Elasticsearch instances
resource "aws_volume_attachment" "elk_data_attachment" {
  count       = var.elk_data_node_count
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.elk_data[count.index].id
  instance_id = aws_instance.elasticsearch[count.index].id
}

# Elastic IP for Kibana (Public Access)
resource "aws_eip" "kibana" {
  domain = "vpc"

  tags = {
    Name = "${var.env}-kibana-eip"
    Env  = var.env
  }
}

# Kibana Instance (Public Subnet with EIP)
resource "aws_instance" "kibana" {
  ami                    = var.elk_ami_id
  instance_type          = var.elk_kibana_instance_type
  subnet_id              = aws_subnet.public-subnet[0].id
  vpc_security_group_ids = [aws_security_group.kibana_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.elk_profile.name
  key_name               = var.bastion_key_name

  user_data = local.kibana_user_data

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name = "${var.env}-kibana"
    Env  = var.env
    Role = "kibana"
  }

  depends_on = [aws_instance.elasticsearch]

  lifecycle {
    ignore_changes = [ami]
  }
}

# Associate EIP with Kibana instance
resource "aws_eip_association" "kibana" {
  instance_id   = aws_instance.kibana.id
  allocation_id = aws_eip.kibana.id
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "elk_logs" {
  name              = "/aws/ec2/elk/${var.env}"
  retention_in_days = var.elk_log_retention_days

  tags = {
    Name = "${var.env}-elk-logs"
    Env  = var.env
  }
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "elasticsearch_cpu" {
  count               = var.elk_data_node_count
  alarm_name          = "${var.env}-elasticsearch-${count.index + 1}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = var.elk_cpu_alarm_threshold

  dimensions = {
    InstanceId = aws_instance.elasticsearch[count.index].id
  }

  tags = {
    Name = "${var.env}-es-cpu-alarm-${count.index + 1}"
    Env  = var.env
  }
}

resource "aws_cloudwatch_metric_alarm" "elasticsearch_disk" {
  count               = var.elk_data_node_count
  alarm_name          = "${var.env}-elasticsearch-${count.index + 1}-low-disk"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "DiskUsedPercent"
  namespace           = "ELK/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"

  dimensions = {
    InstanceId = aws_instance.elasticsearch[count.index].id
  }

  tags = {
    Name = "${var.env}-es-disk-alarm-${count.index + 1}"
    Env  = var.env
  }
}

# Data source for AWS account ID
data "aws_caller_identity" "current" {}
