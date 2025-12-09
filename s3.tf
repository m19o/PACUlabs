# ========================================
# S3 Buckets with Misconfigured Permissions
# ========================================

# Public bucket - intentionally misconfigured
resource "aws_s3_bucket" "public_data" {
  bucket = "${var.lab_name}-public-data-${random_id.bucket_suffix.hex}"

  tags = {
    Name        = "Public Data Bucket"
    Description = "Bucket with public read access - intentional misconfig"
    Sensitivity = "Low"
  }
}

resource "aws_s3_bucket_public_access_block" "public_data" {
  bucket = aws_s3_bucket.public_data.id

  # VULNERABILITY: Public access allowed
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets  = false
}

resource "aws_s3_bucket_policy" "public_data" {
  bucket = aws_s3_bucket.public_data.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.public_data.arn}/*"
      }
    ]
  })
}

resource "aws_s3_object" "public_file" {
  bucket  = aws_s3_bucket.public_data.id
  key     = "public-info.txt"
  content = "This is public information. Nothing sensitive here."
}

resource "aws_s3_object" "public_hint" {
  bucket  = aws_s3_bucket.public_data.id
  key     = "hints/bucket-structure.txt"
  content = "There are other buckets in this account. Look for private buckets with weak ACLs."
}

# Private bucket with weak ACLs
resource "aws_s3_bucket" "private_data" {
  bucket = "${var.lab_name}-private-data-${random_id.bucket_suffix.hex}"

  tags = {
    Name        = "Private Data Bucket"
    Description = "Bucket that should be private but has weak ACLs"
    Sensitivity = "Medium"
  }
}

resource "aws_s3_bucket_public_access_block" "private_data" {
  bucket = aws_s3_bucket.private_data.id

  block_public_acls       = true
  block_public_policy     = false  # Allow bucket policy (for authenticated users)
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# VULNERABILITY: Bucket policy allows authenticated AWS users
resource "aws_s3_bucket_policy" "private_data" {
  bucket = aws_s3_bucket.private_data.id

  # Ensure public access block is updated first
  depends_on = [aws_s3_bucket_public_access_block.private_data]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AuthenticatedRead"
        Effect = "Allow"
        Principal = {
          AWS = "*"  # VULNERABILITY: Any authenticated AWS user
        }
        Action   = ["s3:GetObject", "s3:ListBucket"]
        Resource = [
          aws_s3_bucket.private_data.arn,
          "${aws_s3_bucket.private_data.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_s3_object" "private_file" {
  bucket  = aws_s3_bucket.private_data.id
  key     = "internal-document.pdf"
  content = "Confidential internal document - should not be accessible to all authenticated users!"
}

resource "aws_s3_object" "private_config" {
  bucket  = aws_s3_bucket.private_data.id
  key     = "config/database-credentials.json"
  content = jsonencode({
    db_host     = "prod-db.internal"
    db_username = "admin"
    db_password = "ProdPassword123!"
    api_keys    = ["key1", "key2"]
  })
}

# Secrets bucket - should be very restricted
resource "aws_s3_bucket" "secrets" {
  bucket = "${var.lab_name}-secrets-${random_id.bucket_suffix.hex}"

  tags = {
    Name        = "Secrets Bucket"
    Description = "Bucket containing sensitive secrets"
    Sensitivity = "High"
  }
}

resource "aws_s3_bucket_public_access_block" "secrets" {
  bucket = aws_s3_bucket.secrets.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# VULNERABILITY: Policy allows the compromised user and dev role
resource "aws_s3_bucket_policy" "secrets" {
  bucket = aws_s3_bucket.secrets.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CompromisedUserAccess"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_user.lab_user.arn
        }
        Action   = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"]
        Resource = [
          aws_s3_bucket.secrets.arn,
          "${aws_s3_bucket.secrets.arn}/*"
        ]
      },
      {
        Sid    = "DevRoleAccess"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.dev_role.arn
        }
        Action   = ["s3:*"]
        Resource = [
          aws_s3_bucket.secrets.arn,
          "${aws_s3_bucket.secrets.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_s3_object" "api_keys" {
  bucket  = aws_s3_bucket.secrets.id
  key     = "api-keys/production-keys.txt"
  content = <<-EOT
    Production API Keys:
    - Stripe API Key: sk_live_51AbCdEfGhIjKlMnOpQrStUvWxYz123456
    - AWS Access Key: AKIAEXAMPLE123456789
    - Database Password: SuperSecretProdPass!
  EOT
}

resource "aws_s3_object" "ssh_keys" {
  bucket  = aws_s3_bucket.secrets.id
  key     = "ssh-keys/prod-server-key.pem"
  content = "-----BEGIN RSA PRIVATE KEY-----\n(Simulated private key for lab purposes)\n-----END RSA PRIVATE KEY-----"
}

# Backup bucket in another region (for exfiltration demo)
resource "aws_s3_bucket" "backup_data" {
  count    = var.enable_cross_region_exfil ? 1 : 0
  provider = aws.backup_region
  bucket   = "${var.lab_name}-backup-data-${random_id.bucket_suffix.hex}"

  tags = {
    Name        = "Backup Data Bucket"
    Description = "Backup bucket in different region - may be unmonitored"
    Sensitivity = "High"
    Region      = var.backup_region
  }
}

resource "aws_s3_object" "backup_secrets" {
  count    = var.enable_cross_region_exfil ? 1 : 0
  provider = aws.backup_region
  bucket   = aws_s3_bucket.backup_data[0].id
  key      = "backups/user-data-backup.tar.gz"
  content  = "Simulated backup archive containing user PII and sensitive data"
}

# Random ID for bucket name uniqueness
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

