resource "aws_security_group" "mongodb_sg" {
  name        = "${var.env}-mongodb-sg"
  description = "Security group for MongoDB instance"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port       = 27017
    to_port         = 27017
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]  # Allow access from bastion host
  }

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]  # Allow SSH from bastion host
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.env}-mongodb-sg"
    Env  = var.env
  }
}

resource "aws_instance" "mongodb" {
  ami                    = var.mongodb_ami_id
  instance_type         = var.mongodb_instance_type
  key_name              = var.bastion_key_name  # Using the same key as bastion for simplicity
  subnet_id             = aws_subnet.private-subnet[1].id  # Using private subnet 2
  vpc_security_group_ids = [aws_security_group.mongodb_sg.id]

  root_block_device {
    volume_size = var.mongodb_volume_size
    volume_type = "gp3"
  }

  user_data = <<-EOF
              #!/bin/bash
              set -eux
              
              # Update package lists
              apt-get update
              
              # Install prerequisites
              DEBIAN_FRONTEND=noninteractive apt-get install -y gnupg curl
              
              # Add MongoDB GPG key
              curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | \
                gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg --dearmor
              
              # Add MongoDB repository
              echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | \
                tee /etc/apt/sources.list.d/mongodb-org-7.0.list
              
              # Update package lists again
              apt-get update
              
              # Install MongoDB
              DEBIAN_FRONTEND=noninteractive apt-get install -y mongodb-org
              
              # Enable and start MongoDB service
              systemctl enable mongod
              systemctl start mongod
              
              # Update MongoDB configuration to listen on all interfaces
              sed -i 's/bindIp: 127.0.0.1/bindIp: 0.0.0.0/' /etc/mongod.conf
              systemctl restart mongod
              EOF

  tags = {
    Name = "${var.env}-mongodb"
    Env  = var.env
  }

  depends_on = [aws_subnet.private-subnet]
}