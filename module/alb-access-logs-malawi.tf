resource "aws_s3_bucket" "malawi_alb_access_logs" {
  bucket = "malawi-pg-alb-access-logs"
  # acl    = "private" # Deprecated, removed

  tags = {
    Name        = "Malawi ALB Access Logs"
    Environment = var.env
    Country     = "Malawi"
    ManagedBy   = "Terraform"
  }
}

resource "aws_s3_bucket_public_access_block" "malawi_alb_access_logs" {
  bucket = aws_s3_bucket.malawi_alb_access_logs.id

  block_public_acls   = true
  block_public_policy = true
  ignore_public_acls  = true
  restrict_public_buckets = true
}

# Ensure bucket owner owns objects written by ALB (avoids ACL issues)
resource "aws_s3_bucket_ownership_controls" "malawi_alb_access_logs" {
  bucket = aws_s3_bucket.malawi_alb_access_logs.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_versioning" "malawi_alb_access_logs" {
  bucket = aws_s3_bucket.malawi_alb_access_logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Optionally, add a lifecycle rule to expire logs after 90 days
resource "aws_s3_bucket_lifecycle_configuration" "malawi_alb_access_logs" {
  bucket = aws_s3_bucket.malawi_alb_access_logs.id

  rule {
    id     = "ExpireOldLogs"
    status = "Enabled"

    expiration {
      days = 90
    }
    filter {
      prefix = "AWSLogs/"
    }
  }
}

# Bucket policy to allow ALB log delivery
resource "aws_s3_bucket_policy" "malawi_alb_access_logs" {
  bucket = aws_s3_bucket.malawi_alb_access_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AWSLogDeliveryWrite"
        Effect   = "Allow"
        Principal = {
          Service = "logdelivery.elasticloadbalancing.amazonaws.com"
        }
        Action   = [
          "s3:PutObject",
          "s3:PutObjectAcl"
        ]
        Resource = "${aws_s3_bucket.malawi_alb_access_logs.arn}/eks-alb/AWSLogs/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
      {
        Sid      = "AWSLogDeliveryAclCheck"
        Effect   = "Allow"
        Principal = {
          Service = "logdelivery.elasticloadbalancing.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.malawi_alb_access_logs.arn
      }
    ]
  })
}
