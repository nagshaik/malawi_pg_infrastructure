# Terraform EKS Infrastructure

This directory contains Terraform configuration for the Malawi PG infrastructure, including EKS cluster, networking, bastion, databases (RDS, MongoDB), caching (ElastiCache Redis), messaging (MSK Kafka), and logging (Elasticsearch/Kibana).

## Prerequisites

- Terraform >= 1.0
- AWS CLI configured with appropriate credentials
- kubectl (for EKS cluster interaction)
- SSH key pair created in AWS (specified in `bastion_key_name`)

## Environment Configuration

Variables are defined in `dev.tfvars`. To use a different environment, create a new `.tfvars` file (e.g., `staging.tfvars`, `prod.tfvars`) with environment-specific values.

## Usage

### Initialize Terraform
```powershell
cd terraform\eks
terraform init
```

### Plan Changes
```powershell
# Using dev.tfvars
terraform plan -var-file=dev.tfvars

# Or for a different environment
terraform plan -var-file=staging.tfvars
```

### Apply Configuration
```powershell
# Using dev.tfvars
terraform apply -var-file=dev.tfvars

# Or for a different environment
terraform apply -var-file=prod.tfvars
```

### Destroy Resources
```powershell
terraform destroy -var-file=dev.tfvars
```

### View State
```powershell
# List all resources
terraform state list

# Show details of a specific resource
terraform state show module.eks.aws_eks_cluster.eks[0]
```

## AWS Credentials

**Do not hardcode credentials in `.tfvars` files.** Use one of the following methods:

### Option 1: Environment Variables (Recommended)
```powershell
$env:AWS_ACCESS_KEY_ID="your-access-key"
$env:AWS_SECRET_ACCESS_KEY="your-secret-key"
$env:AWS_DEFAULT_REGION="eu-central-1"
```

### Option 2: AWS CLI Profile
```powershell
# Configure profile
aws configure --profile malawi-pg

# Use with Terraform
$env:AWS_PROFILE="malawi-pg"
terraform plan -var-file=dev.tfvars
```

### Option 3: EC2 Instance Profile / IAM Role
When running Terraform from an EC2 instance or AWS service with an attached IAM role, credentials are automatically retrieved.

## Key Configuration

### EKS Cluster
- **Version**: 1.34
- **Node Groups**: On-demand m5.large instances
- **Addons**: VPC CNI, CoreDNS, kube-proxy, EBS CSI driver
- **Networking**: Private + public endpoint access

### Bastion Host
- **Purpose**: Secure access to private resources (EKS, MongoDB, RDS)
- **Instance**: m5.xlarge Ubuntu
- **Key**: `kenya-pg-key`

### Databases
- **RDS MySQL**: 8.0.42, db.m5.large, 300GB
- **MongoDB**: Self-managed on EC2, m6i.large, 500GB EBS
- **ElastiCache Redis**: 7.1, cache.t3.medium, 2 nodes (Multi-AZ)

### Messaging
- **MSK Kafka**: 3.5.1, kafka.m5.large, 2 brokers, 100GB EBS per broker

### Logging
- **Elasticsearch**: Self-managed on EC2, r6i.large, 8GB heap, 250GB EBS
- **Kibana**: t3.large, exposed via ALB
- **Fluent Bit**: DaemonSet in EKS (see `k8s-manifests/logging/`)

## Post-Apply Steps

1. **Configure kubectl**:
   ```powershell
   aws eks update-kubeconfig --name malawi-pg-malawi-pg-eks --region eu-central-1
   ```

2. **Install AWS Load Balancer Controller**:
   ```powershell
   &"C:\Program Files\Lens\resources\x64\kubectl.exe" apply -f k8s-manifests/aws-load-balancer-controller.yaml
   ```

3. **Deploy Fluent Bit** (see `k8s-manifests/logging/README.md`):
   ```powershell
   &"C:\Program Files\Lens\resources\x64\kubectl.exe" apply -f k8s-manifests/logging/
   ```

4. **Access Bastion**:
   ```powershell
   ssh -i path\to\kenya-pg-key.pem ubuntu@<bastion-eip>
   ```

## Directory Structure

- `main.tf` - Root module calling `../module`
- `variables.tf` - Variable definitions
- `outputs.tf` - Outputs (cluster endpoint, bastion IP, etc.)
- `providers.tf` - AWS provider configuration
- `backend.tf` - Terraform state backend (S3)
- `dev.tfvars` - Development environment variables
- `aws_auth.tf` - EKS aws-auth ConfigMap placeholder

## Notes

- **Security**: Bastion `allowed_cidr` is set to `0.0.0.0/0` in dev; restrict in production.
- **State**: Backend configured for S3; ensure bucket exists before `terraform init`.
- **Cost**: Running all resources (EKS, RDS, MSK, Elasticsearch) incurs ~$500-1000/month in eu-central-1.

## Troubleshooting

- **EKS not accessible**: Check `endpoint_public_access = true` and security groups.
- **Node group fails**: Verify IAM role policies and subnet tags for EKS.
- **State lock errors**: Check S3 bucket and DynamoDB lock table.
- **ALB not provisioning**: Ensure AWS Load Balancer Controller is installed and IRSA role is correct.

For more details, see the main [README.md](../../README.md) in the repo root.
