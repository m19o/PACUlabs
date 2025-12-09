# ========================================
# Additional Providers for Cross-Region Resources
# ========================================

# Provider for backup region (unmonitored)
provider "aws" {
  alias  = "backup_region"
  region = var.backup_region

  default_tags {
    tags = {
      Project     = "PACU-Labs"
      Environment = "Educational"
      Purpose     = "Security-Training"
      ManagedBy   = "Terraform"
    }
  }
}

