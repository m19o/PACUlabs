output "compromised_user_credentials" {
  description = "Compromised IAM user credentials for lab"
  value = {
    access_key_id     = aws_iam_access_key.lab_user.id
    secret_access_key = aws_iam_access_key.lab_user.secret
    username          = aws_iam_user.lab_user.name
    region            = var.aws_region
    account_id        = data.aws_caller_identity.current.account_id
  }
  sensitive = true
  
  depends_on = [data.aws_caller_identity.current]
}

output "lab_instructions" {
  description = "Instructions for students"
  value = <<-EOT
    ============================================
    PACU Lab Environment - Ready for Attack
    ============================================
    
    Your compromised credentials:
    - Access Key ID: ${aws_iam_access_key.lab_user.id}
    - Secret Access Key: (see sensitive outputs)
    
    Region: ${var.aws_region}
    
    Lab Objectives:
    1. Enumerate IAM permissions and identify privilege escalation paths
    2. Discover EC2 instances and attempt instance profile abuse
    3. Find and access misconfigured S3 buckets
    4. Explore role chaining opportunities via STS
    5. Identify CloudTrail blind spots
    6. Practice data exfiltration techniques
    7. Establish persistence mechanisms
    
    Remember: This is for educational purposes only.
  EOT
  sensitive = true
}

output "vpc_id" {
  description = "VPC ID for the lab environment"
  value       = aws_vpc.lab_vpc.id
}

output "compromised_instance_ips" {
  description = "IP addresses of EC2 instances with compromised roles"
  value = {
    web_server = aws_instance.web_server.public_ip
    dev_server = aws_instance.dev_server.private_ip
    data_server = aws_instance.data_server.private_ip
  }
}

output "s3_bucket_names" {
  description = "S3 bucket names in the environment"
  value = {
    public_bucket     = aws_s3_bucket.public_data.bucket
    private_bucket    = aws_s3_bucket.private_data.bucket
    secrets_bucket    = aws_s3_bucket.secrets.bucket
    backup_bucket     = var.enable_cross_region_exfil ? aws_s3_bucket.backup_data[0].bucket : "not-enabled"
  }
}

