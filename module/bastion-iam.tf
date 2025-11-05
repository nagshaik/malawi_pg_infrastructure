resource "aws_iam_role" "bastion_role" {
  name = "${var.env}-bastion-role"

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
    Name = "${var.env}-bastion-role"
    Env  = var.env
  }
}

resource "aws_iam_instance_profile" "bastion_profile" {
  name = "${var.env}-bastion-profile"
  role = aws_iam_role.bastion_role.name
}

resource "aws_iam_role_policy_attachment" "bastion_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.bastion_role.name
}

resource "aws_iam_role_policy" "bastion_policy" {
  name = "${var.env}-bastion-policy"
  role = aws_iam_role.bastion_role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          # EKS read access for kubeconfig generation and cluster info
          "eks:DescribeCluster",
          "eks:ListClusters",
          "eks:ListNodegroups",
          "eks:DescribeNodegroup",
          "eks:ListFargateProfiles",
          "eks:DescribeFargateProfile",

          # STS required by some tooling for identity
          "sts:GetCallerIdentity",

          # EC2 read-only to inspect instances/regions if needed
          "ec2:DescribeInstances",
          "ec2:DescribeRegions",

          # ECR read to pull images if you use CLI from bastion
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:GetRepositoryPolicy",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      }
    ]
  })
}