resource "aws_s3_bucket" "kenya_alb_access_logs" {
  bucket = "kenya-pg-alb-access-logs"

  tags = {
    Name        = "Kenya ALB Access Logs"
    Environment = var.env
    Country     = "Kenya"
    ManagedBy   = "Terraform"
  }
}

resource "aws_s3_bucket_public_access_block" "kenya_alb_access_logs" {
  bucket = aws_s3_bucket.kenya_alb_access_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "kenya_alb_access_logs" {
  bucket = aws_s3_bucket.kenya_alb_access_logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "kenya_alb_access_logs" {
  bucket = aws_s3_bucket.kenya_alb_access_logs.id

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

resource "aws_s3_bucket_policy" "kenya_alb_access_logs" {
  bucket = aws_s3_bucket.kenya_alb_access_logs.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid = "AWSLogDeliveryWrite",
        Effect = "Allow",
        Principal = {
          Service = "logdelivery.elasticloadbalancing.amazonaws.com"
        },
        Action = "s3:PutObject",
        Resource = "${aws_s3_bucket.kenya_alb_access_logs.arn}/eks-alb/AWSLogs/*",
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
      {
        Sid = "AWSLogDeliveryAclCheck",
        Effect = "Allow",
        Principal = {
          Service = "logdelivery.elasticloadbalancing.amazonaws.com"
        },
        Action = "s3:GetBucketAcl",
        Resource = aws_s3_bucket.kenya_alb_access_logs.arn
      }
    ]
  })
}
