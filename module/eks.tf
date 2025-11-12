resource "aws_eks_cluster" "eks" {

  count    = var.is-eks-cluster-enabled == true ? 1 : 0
  name     = var.cluster-name
  role_arn = aws_iam_role.eks-cluster-role[count.index].arn
  version  = var.cluster-version

  vpc_config {
    subnet_ids              = [aws_subnet.private-subnet[0].id, aws_subnet.private-subnet[1].id]
    endpoint_private_access = var.endpoint-private-access
    endpoint_public_access  = var.endpoint-public-access
  }


  access_config {
    authentication_mode                         = "CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  tags = {
    Name = var.cluster-name
    Env  = var.env
  }
}

# OIDC Provider
resource "aws_iam_openid_connect_provider" "eks-oidc" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks-certificate.certificates[0].sha1_fingerprint]
  url             = data.tls_certificate.eks-certificate.url
}


# AddOns for EKS Cluster
resource "aws_eks_addon" "eks-addons" {
  for_each      = { for idx, addon in var.addons : idx => addon }
  cluster_name  = aws_eks_cluster.eks[0].name
  addon_name    = each.value.name
  addon_version = each.value.version

  depends_on = [
    aws_eks_node_group.ondemand-node
  ]
}

# NodeGroups
resource "aws_eks_node_group" "ondemand-node" {
  for_each = {
    node1 = aws_subnet.private-subnet[0].id
    node2 = aws_subnet.private-subnet[1].id
  }

  cluster_name    = aws_eks_cluster.eks[0].name
  node_group_name = "${var.cluster-name}-on-demand-nodes-${each.key}"
  node_role_arn   = aws_iam_role.eks-nodegroup-role[0].arn

  scaling_config {
    desired_size = var.desired_capacity_on_demand
    min_size     = var.min_capacity_on_demand
    max_size     = var.max_capacity_on_demand
  }

  subnet_ids = [each.value]

  instance_types = var.ondemand_instance_types
  capacity_type  = "ON_DEMAND"
  
  disk_size = 50  # 50 GB storage per node
  
  labels = {
    type = "ondemand"
    zone = each.key
  }

  update_config {
    max_unavailable = 1
  }
  
  tags = {
    "Name" = "${var.cluster-name}-ondemand-nodes-${each.key}"
  }
  tags_all = {
    "kubernetes.io/cluster/${var.cluster-name}" = "owned"
    "Name"                                      = "${var.cluster-name}-ondemand-nodes-${each.key}"
  }

  depends_on = [aws_eks_cluster.eks]
}

