variable "aws_region" {
  description = "AWS region for lab resources"
  type        = string
  default     = "us-east-1"
}

variable "lab_name" {
  description = "Name prefix for all lab resources"
  type        = string
  default     = "paculabs"
}

variable "student_password" {
  description = "Password for compromised user account (default: ChangeMe123!)"
  type        = string
  default     = "ChangeMe123!"
  sensitive   = true
}

variable "enable_cloudtrail" {
  description = "Whether to enable CloudTrail (will have blind spots for demo)"
  type        = bool
  default     = true
}

variable "enable_cross_region_exfil" {
  description = "Enable resources in additional region for exfiltration demo"
  type        = bool
  default     = true
}

variable "backup_region" {
  description = "Backup region for exfiltration demo (unmonitored region)"
  type        = string
  default     = "us-west-2"
}

variable "enable_secrets_manager" {
  description = "Enable AWS Secrets Manager (costs $0.40/secret/month - not free tier)"
  type        = bool
  default     = true
}

variable "enable_vpc_interface_endpoints" {
  description = "Enable VPC Interface Endpoints (STS endpoint costs ~$0.01/hour - not free tier)"
  type        = bool
  default     = true
}

