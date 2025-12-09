# ========================================
# CloudTrail with Intentional Blind Spots
# ========================================

# S3 bucket for CloudTrail logs
resource "aws_s3_bucket" "cloudtrail_logs" {
  bucket = "${var.lab_name}-cloudtrail-logs-${random_id.bucket_suffix.hex}"

  tags = {
    Name        = "CloudTrail Logs"
    Description = "Bucket for CloudTrail log storage"
  }
}

resource "aws_s3_bucket_public_access_block" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.cloudtrail_logs.arn
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = "arn:aws:cloudtrail:${var.aws_region}:${data.aws_caller_identity.current.account_id}:trail/${var.lab_name}-trail"
          }
        }
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail_logs.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = "arn:aws:cloudtrail:${var.aws_region}:${data.aws_caller_identity.current.account_id}:trail/${var.lab_name}-trail"
            "s3:x-amz-acl"  = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

# CloudTrail configuration
# NOTE: Event selectors are configured inline in newer provider versions
resource "aws_cloudtrail" "lab_trail" {
  count         = var.enable_cloudtrail ? 1 : 0
  name          = "${var.lab_name}-trail"
  s3_bucket_name = aws_s3_bucket.cloudtrail_logs.id

  # VULNERABILITY: Not a multi-region trail
  is_multi_region_trail = false
  
  # VULNERABILITY: Not organization-wide
  is_organization_trail = false

  # VULNERABILITY: Some event types not logged
  enable_logging                = true
  include_global_service_events = false  # Won't log IAM events globally!

  # VULNERABILITY: No SNS notifications
  sns_topic_name = null

  # VULNERABILITY: Not encrypted
  enable_log_file_validation = false
  kms_key_id                 = null

  # VULNERABILITY: CloudWatch Logs not configured
  cloud_watch_logs_group_arn = null

  # Logging data events for S3 buckets in us-east-1
  # This shows CloudTrail IS working in us-east-1
  # VULNERABILITY: Only logs us-east-1, not other regions (us-west-2 blind spot!)
  # Note: CloudTrail requires specific bucket ARNs, not wildcards
  event_selector {
    read_write_type           = "All"
    include_management_events = true

    data_resource {
      type   = "AWS::S3::Object"
      # Log specific buckets in us-east-1 (working trail)
      # us-west-2 buckets will NOT be logged (blind spot)
      values = [
        "${aws_s3_bucket.public_data.arn}/",
        "${aws_s3_bucket.private_data.arn}/",
        "${aws_s3_bucket.secrets.arn}/",
        "${aws_s3_bucket.cloudtrail_logs.arn}/"
      ]
    }
  }

  depends_on = [aws_s3_bucket_policy.cloudtrail_logs]

  tags = {
    Name        = "Lab CloudTrail"
    Description = "CloudTrail with intentional blind spots"
  }
}

# Data source for current AWS account
data "aws_caller_identity" "current" {}

