# Malawi PG Infrastructure Architecture

## 🏗️ Current Architecture (Post-Cleanup)

### Infrastructure Components

```
Internet (Public)
    ↓
API Gateway (HTTP API v2) - Public Endpoint
    ↓ [VPC Link]
Network Load Balancer (Internal) - Private Subnets
    ↓ [Target Groups: HTTP/HTTPS/8080]
EKS Cluster (Private)
    ↓ [NodePort Services]
Application Pods
```

---

## 📁 Project Structure

### Core Terraform Files

**`eks/` - EKS Infrastructure**
- `main.tf` - EKS cluster configuration
- `nlb.tf` - Internal NLB with 3 target groups (HTTP/HTTPS/8080)
- `vpc-link.tf` - API Gateway + VPC Link for public access
- `outputs.tf` - Infrastructure outputs
- `variables.tf` - Input variables
- `providers.tf` - AWS provider configuration
- `backend.tf` - S3 backend for state
- `aws_auth.tf` - Kubernetes AWS auth config
- `dev.tfvars` - Development environment variables

**`module/` - VPC & Supporting Services**
- `vpc.tf` - VPC, subnets, NAT, IGW
- `eks.tf` - EKS cluster module
- `bastion.tf` - Bastion host in public subnet
- `bastion-iam.tf` - Bastion IAM roles
- `rds.tf` - PostgreSQL RDS
- `mongodb.tf` - DocumentDB cluster
- `kafka.tf` - MSK Kafka cluster
- `redis.tf` - ElastiCache Redis
- `gather.tf` - OpenSearch/ELK cluster
- `iam.tf` - IAM roles and policies
- `outputs.tf` - Module outputs
- `variables.tf` - Module variables

### Kubernetes Manifests

**`k8s-manifests/nlb/` - Demo Application**
- `00-namespace.yaml` - demo-app namespace
- `01-deployment.yaml` - NGINX deployment (3 replicas)
- `02-service.yaml` - NodePort service (port 30080)
- `README.md` - NLB setup and troubleshooting guide
- `VPC_LINK_README.md` - API Gateway + VPC Link documentation

### Scripts

**Active Scripts:**
- `register_nlb_targets.ps1` - Automate NLB target registration
- `diagnose_nlb.ps1` - Comprehensive NLB diagnostics
- `patch_aws_auth.ps1` - Update EKS aws-auth ConfigMap
- `install-bastion-tools.sh` - Install kubectl, AWS CLI, ArgoCD on bastion
- `fix-bastion-tools.sh` - Fix bastion tool installations

### Documentation

- `README.md` - Project overview
- `ARCHITECTURE.md` - This file
- `ELK_SETUP.md` - OpenSearch/ELK setup guide
- `KAFKA_SETUP.md` - MSK Kafka setup guide
- `REDIS_SETUP.md` - ElastiCache Redis setup guide

---

## 🌐 Networking Architecture

### VPC Configuration
- **CIDR**: `10.16.0.0/16`
- **Availability Zones**: 2 (eu-central-1a, eu-central-1b)
- **Public Subnets**: `10.16.0.0/20`, `10.16.16.0/20`
- **Private Subnets**: `10.16.128.0/20`, `10.16.144.0/20`

### Load Balancing Strategy

**Internal NLB (Private)**
- Type: Network Load Balancer
- Scheme: Internal (private subnets only)
- Target Type: IP
- Cross-Zone Load Balancing: Enabled
- Target Groups:
  - HTTP (port 80)
  - HTTPS (port 443)
  - Application (port 8080)

**API Gateway + VPC Link**
- Protocol: HTTP API v2
- Endpoint: Public (internet-accessible)
- Integration: HTTP_PROXY to internal NLB
- VPC Link: Connects API Gateway to private NLB
- CORS: Enabled for all origins
- Throttling: 10,000 req/sec rate, 5,000 burst

### Security Groups

**NLB Security Group**
- Ingress: Allow TCP from VPC CIDR (`10.16.0.0/16`)
- Egress: Allow all outbound

**Bastion Security Group**
- Ingress: SSH (22), HTTPS (443), RDP (3389) from allowed CIDRs
- Egress: Allow all outbound

**EKS Cluster Security Group**
- Ingress: Allow traffic from NLB security group
- Managed by EKS

---

## 🔐 Security Architecture

### Public Access Path
```
Internet → API Gateway (Public) → VPC Link → NLB (Private) → EKS (Private)
```

### Internal Access Path
```
Bastion (Public Subnet) → NLB (Private Subnet) → EKS (Private Subnet)
```

### Key Security Features
- ✅ EKS cluster NOT directly exposed to internet
- ✅ Internal NLB in private subnets only
- ✅ API Gateway provides public endpoint with throttling
- ✅ VPC Link creates secure ENI in private subnets
- ✅ Bastion host for administrative access
- ✅ IAM roles for service accounts (IRSA)

---

## 📊 Supporting Services

### Database Layer
- **PostgreSQL RDS**: Primary relational database
- **MongoDB (DocumentDB)**: Document database
- **Redis (ElastiCache)**: Caching layer

### Data Streaming
- **Kafka (MSK)**: Event streaming platform

### Observability
- **OpenSearch (ELK)**: Log aggregation and search
- **CloudWatch**: Metrics and API Gateway logs

---

## 🚀 Deployment Workflow

### 1. Infrastructure Deployment
```powershell
cd C:\Users\nagin\malawi-pg-infra\eks
terraform init
terraform plan -var-file=dev.tfvars
terraform apply -var-file=dev.tfvars
```

### 2. Deploy Applications to EKS
```bash
# From bastion host
kubectl apply -f k8s-manifests/nlb/
```

### 3. Register NLB Targets
```powershell
# From Windows
.\scripts\register_nlb_targets.ps1

# Or from bastion
aws elbv2 register-targets --target-group-arn <arn> --targets Id=<node-ip>,Port=30080
```

### 4. Access Applications
```bash
# Get API Gateway endpoint
terraform output api_gateway_endpoint

# Access from internet
curl https://<api-gateway-id>.execute-api.eu-central-1.amazonaws.com/
```

---

## 🔍 Troubleshooting

### Check NLB Target Health
```powershell
.\scripts\diagnose_nlb.ps1
```

### Check API Gateway Status
```bash
aws apigatewayv2 get-vpc-links --region eu-central-1
```

### Check EKS Services
```bash
kubectl get svc -A
kubectl get pods -A
kubectl get nodes -o wide
```

### Common Issues

**"Service Unavailable" from API Gateway**
- Cause: No healthy targets in NLB
- Solution: Register targets with `register_nlb_targets.ps1`

**Target Health "unhealthy"**
- Cause: NodePort service not listening or pods not running
- Solution: Check `kubectl get pods -n <namespace>`

**Cannot reach API Gateway**
- Cause: VPC Link not in AVAILABLE state
- Solution: Check VPC Link status, verify subnets and security groups

---

## 📈 Scalability

- **EKS Node Group**: Auto-scaling enabled
- **NLB**: Cross-zone load balancing for high availability
- **API Gateway**: Auto-scales with throttling limits
- **Multi-AZ**: All services deployed across 2 availability zones

---

## 💰 Cost Optimization

- **Internal NLB**: Lower data transfer costs vs public ALB
- **API Gateway**: Pay-per-request pricing with caching
- **Spot Instances**: Can be enabled for non-production workloads
- **Right-sizing**: Review instance types regularly

---

## 📝 Next Steps

1. ✅ **Infrastructure deployed** - NLB, VPC Link, API Gateway ready
2. ⚠️ **Register NLB targets** - Run `register_nlb_targets.ps1`
3. ⚠️ **Deploy applications** - Apply K8s manifests
4. ⚠️ **Test end-to-end** - Verify API Gateway → NLB → EKS flow
5. 🔄 **Monitor** - Set up CloudWatch dashboards and alarms

---

## 🔗 Key Outputs

```bash
# Get all outputs
terraform output

# Specific outputs
terraform output api_gateway_endpoint
terraform output nlb_dns_name
terraform output eks_cluster_endpoint
```

---

**Last Updated**: November 7, 2025
**Architecture Version**: 2.0 (Post-ALB Removal, NLB + API Gateway)
