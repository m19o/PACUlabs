# ========================================
# Persistence Mechanisms for Lab Demo
# ========================================

# Create zip file for Lambda
data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "lambda_function.zip"
  source {
    content  = "def handler(event, context): return {'statusCode': 200}"
    filename = "index.py"
  }
}

# Lambda function that can be used for persistence
resource "aws_lambda_function" "backup_function" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "${var.lab_name}-backup-function"
  role            = aws_iam_role.lambda_service_role.arn
  handler         = "index.handler"
  runtime         = "python3.9"
  timeout         = 30
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  # VULNERABILITY: Lambda environment variables may contain secrets
  environment {
    variables = {
      BACKUP_BUCKET = var.enable_cross_region_exfil ? aws_s3_bucket.backup_data[0].id : "backup-bucket-not-enabled"
      API_KEY       = "hardcoded-api-key-12345"  # Should be in Secrets Manager!
      DB_PASSWORD   = "WeakPassword!"
    }
  }

  tags = {
    Name        = "Backup Lambda Function"
    Description = "Lambda function that can be hijacked for persistence"
  }
}

# VPC endpoint for S3 (might be used for data exfiltration)
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.lab_vpc.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [
    aws_route_table.private_rt.id
  ]

  tags = {
    Name = "${var.lab_name}-s3-endpoint"
  }
}

# VPC endpoint for STS (for role assumption)
# NOTE: Interface Endpoints cost ~$0.01/hour + data processing (NOT free tier)
# Set enable_vpc_interface_endpoints = false to disable and save costs
resource "aws_vpc_endpoint" "sts" {
  count    = var.enable_vpc_interface_endpoints ? 1 : 0
  vpc_id              = aws_vpc.lab_vpc.id
  service_name        = "com.amazonaws.${var.aws_region}.sts"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [
    aws_subnet.private_subnet_1.id,
    aws_subnet.private_subnet_2.id
  ]
  security_group_ids  = [aws_security_group.private_sg.id]
  
  private_dns_enabled = true

  tags = {
    Name = "${var.lab_name}-sts-endpoint"
  }
}

