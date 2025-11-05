resource "aws_security_group" "bastion_sg" {
  name        = "${var.env}-bastion-sg"
  description = "Security group for bastion host"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.bastion_allowed_cidr
    description = "Allow SSH access"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.bastion_allowed_cidr
    description = "Allow HTTPS access"
  }

  ingress {
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = var.bastion_allowed_cidr
    description = "Allow RDP access"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "${var.env}-bastion-sg"
    Env  = var.env
  }
}

resource "aws_instance" "bastion" {
  ami                         = var.bastion_ami_id
  instance_type               = var.bastion_instance_type
  key_name                    = var.bastion_key_name
  subnet_id                   = aws_subnet.public-subnet[0].id
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.bastion_profile.name
  user_data_replace_on_change = true

  root_block_device {
    volume_size = var.bastion_volume_size
    volume_type = "gp3"
  }

  user_data = <<-EOF
              #!/bin/bash
              set -ex
              LOGFILE=/var/log/bastion_user_data.log
              exec > >(tee -a $${LOGFILE}) 2>&1

              # Install prerequisites
              sudo apt-get update -y
              sudo apt-get install -y unzip curl jq wget

              # Install AWS CLI v2
              cd /tmp
              curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip
              unzip -qo awscliv2.zip
              sudo ./aws/install --bin-dir /usr/local/bin --install-dir /usr/local/aws-cli --update
              rm -rf aws awscliv2.zip

              # Install kubectl
              KUBECTL_VER=$(curl -fsSL https://dl.k8s.io/release/stable.txt)
              curl -fsSLO "https://dl.k8s.io/release/$${KUBECTL_VER}/bin/linux/amd64/kubectl"
              chmod +x kubectl
              sudo mv kubectl /usr/local/bin/kubectl

              # Install ArgoCD CLI
              curl -fsSLO "https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64"
              chmod +x argocd-linux-amd64
              sudo mv argocd-linux-amd64 /usr/local/bin/argocd

              # Verify installations
              /usr/local/bin/aws --version
              /usr/local/bin/kubectl version --client
              /usr/local/bin/argocd version --client

              echo "All tools installed successfully!"
              EOF


  tags = {
    Name = "${var.env}-bastion-host"
    Env  = var.env
  }

  depends_on = [aws_subnet.public-subnet]
}

# Allocate an Elastic IP for the bastion and associate it
resource "aws_eip" "bastion" {
  tags = {
    Name = "${var.env}-bastion-eip"
    Env  = var.env
  }
}

resource "aws_eip_association" "bastion" {
  instance_id   = aws_instance.bastion.id
  allocation_id = aws_eip.bastion.allocation_id
}