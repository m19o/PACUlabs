# ========================================
# Secrets Manager with Misconfigurations
# ========================================
# NOTE: Secrets Manager costs $0.40 per secret per month (NOT free tier)
# Set enable_secrets_manager = false in variables to disable

# Secret with weak access policy
resource "aws_secretsmanager_secret" "database_credentials" {
  count = var.enable_secrets_manager ? 1 : 0
  name        = "${var.lab_name}/database/prod-credentials"
  description = "Production database credentials"

  tags = {
    Name        = "Database Credentials"
    Environment = "Production"
  }
}

# VULNERABILITY: Secret version with known or weak encryption
resource "aws_secretsmanager_secret_version" "database_credentials" {
  count     = var.enable_secrets_manager ? 1 : 0
  secret_id = aws_secretsmanager_secret.database_credentials[0].id
  secret_string = jsonencode({
    username = "prod_admin"
    password = "WeakPassword123!"
    host     = "prod-db.example.com"
    port     = 5432
  })
}

# Secret with overly permissive policy
resource "aws_secretsmanager_secret_policy" "database_credentials" {
  count      = var.enable_secrets_manager ? 1 : 0
  secret_arn = aws_secretsmanager_secret.database_credentials[0].arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CompromisedUserAccess"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_user.lab_user.arn
        }
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "*"
      },
      {
        # VULNERABILITY: Authenticated users can read
        Sid    = "AuthenticatedRead"
        Effect = "Allow"
        Principal = {
          AWS = "*"
        }
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = var.enable_secrets_manager ? aws_secretsmanager_secret.database_credentials[0].arn : ""
        Condition = {
          StringEquals = {
            "aws:PrincipalAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

# API keys secret
resource "aws_secretsmanager_secret" "api_keys" {
  count = var.enable_secrets_manager ? 1 : 0
  name        = "${var.lab_name}/api/external-services"
  description = "API keys for external services"

  tags = {
    Name        = "API Keys"
    Environment = "Production"
  }
}

resource "aws_secretsmanager_secret_version" "api_keys" {
  count     = var.enable_secrets_manager ? 1 : 0
  secret_id = aws_secretsmanager_secret.api_keys[0].id
  secret_string = jsonencode({
    stripe_key      = "sk_live_51AbCdEfGhIjKlMnOpQrStUvWxYz"
    sendgrid_key    = "SG.xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
    aws_access_key  = aws_iam_access_key.lab_user.id
    aws_secret_key  = aws_iam_access_key.lab_user.secret
  })
}

# Secret containing temporary credentials for SSM RCE role
# This allows RCE execution through Systems Manager
resource "aws_secretsmanager_secret" "ssm_rce_credentials" {
  count = var.enable_secrets_manager ? 1 : 0
  name        = "${var.lab_name}/ssm/rce-role-credentials"
  description = "Temporary credentials for SSM RCE role - allows RCE execution"

  tags = {
    Name        = "SSM RCE Credentials"
    Environment = "Production"
    Sensitivity = "High"
  }
}

# Generate temporary credentials for SSM RCE role using null_resource
# This uses bash which works on Linux/Mac (and WSL on Windows)
resource "null_resource" "generate_ssm_rce_credentials" {
  count = var.enable_secrets_manager ? 1 : 0
  
  triggers = {
    role_arn = aws_iam_role.ssm_rce_role.arn
    # Force regeneration on each apply
    timestamp = timestamp()
  }

  # Bash for Linux/Mac/WSL
  provisioner "local-exec" {
    command = <<-EOT
      set -e
      CREDS=$(aws sts assume-role \
        --role-arn ${aws_iam_role.ssm_rce_role.arn} \
        --role-session-name terraform-$(date +%s) \
        --duration-seconds 43200 \
        --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken,Expiration]' \
        --output text)
      
      ACCESS_KEY=$(echo "$CREDS" | awk '{print $1}')
      SECRET_KEY=$(echo "$CREDS" | awk '{print $2}')
      SESSION_TOKEN=$(echo "$CREDS" | awk '{print $3}')
      EXPIRATION=$(echo "$CREDS" | awk '{print $4}')
      
      CREDS_JSON=$(cat <<EOF
      {
        "AccessKeyId": "$ACCESS_KEY",
        "SecretAccessKey": "$SECRET_KEY",
        "SessionToken": "$SESSION_TOKEN",
        "RoleArn": "${aws_iam_role.ssm_rce_role.arn}",
        "Expiration": "$EXPIRATION"
      }
      EOF
      )
      
      aws secretsmanager put-secret-value \
        --secret-id ${aws_secretsmanager_secret.ssm_rce_credentials[0].id} \
        --secret-string "$CREDS_JSON"
    EOT
    
    interpreter = ["bash", "-c"]
  }

  depends_on = [
    aws_iam_role.ssm_rce_role,
    aws_secretsmanager_secret.ssm_rce_credentials
  ]
}

# Data source to read credentials from Secrets Manager (for reference)
# Note: This reads what was stored by null_resource, not generating new ones
data "aws_secretsmanager_secret_version" "ssm_rce_credentials" {
  count     = var.enable_secrets_manager ? 1 : 0
  secret_id = aws_secretsmanager_secret.ssm_rce_credentials[0].id
  
  depends_on = [null_resource.generate_ssm_rce_credentials]
}

# Note: Credentials are stored directly by null_resource.generate_ssm_rce_credentials
# using aws secretsmanager put-secret-value command
# No need for aws_secretsmanager_secret_version resource

# Secret policy - allow dev_role to access
resource "aws_secretsmanager_secret_policy" "ssm_rce_credentials" {
  count      = var.enable_secrets_manager ? 1 : 0
  secret_arn = aws_secretsmanager_secret.ssm_rce_credentials[0].arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DevRoleAccess"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.dev_role.arn
        }
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = aws_secretsmanager_secret.ssm_rce_credentials[0].arn
      }
    ]
  })
}

