# IAM Resources with Intentional Vulnerabilities
resource "aws_iam_user" "lab_user" {
  name = "${var.lab_name}-compromised-user"
  path = "/"
  
  tags = {
    Name        = "Compromised User"
    Description = "Initial compromised account for lab"
  }
}

resource "aws_iam_access_key" "lab_user" {
  lifecycle {
    create_before_destroy = true
  }
  user = aws_iam_user.lab_user.name
}

# Weak password policy (intentional misconfiguration)
resource "aws_iam_account_password_policy" "weak_policy" {
  minimum_password_length        = 6  # AWS minimum is 6, this is still weak
  require_uppercase_characters   = false
  require_lowercase_characters   = false
  require_numbers                = false
  require_symbols                = false
  allow_users_to_change_password = true
  max_password_age               = 365  # Too long!
  password_reuse_prevention      = 0    # No reuse prevention!
}

# Minimal permissions policy for enumeration and escalation
resource "aws_iam_user_policy" "user_limited_access" {
  name = "ReadOnlyAccess"
  user = aws_iam_user.lab_user.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sts:GetCallerIdentity"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:ListRoles"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:GetRole",
          "iam:GetRolePolicy"
        ]
        Resource = [
          "arn:aws:iam::*:role/${var.lab_name}-*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "sts:AssumeRole"
        ]
        Resource = [
          "arn:aws:iam::*:role/${var.lab_name}-*"
        ]
      }
    ]
  })
}

# Lambda service role (only Lambda service can assume)
resource "aws_iam_role" "lambda_service_role" {
  name = "${var.lab_name}-lambda-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "Lambda Service Role"
    Description = "Lambda execution role - not vulnerable"
  }
}

# Overprivileged Lambda role
resource "aws_iam_role_policy" "lambda_full_access" {
  name = "FullAccess"
  role = aws_iam_role.lambda_service_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "*"
        Resource = "*"
      }
    ]
  })
}

# EC2 instance profile role (only EC2 service can assume)
resource "aws_iam_role" "ec2_instance_role" {
  name = "${var.lab_name}-ec2-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "EC2 Instance Role"
    Description = "EC2 instance profile role - not vulnerable"
  }
}

# EC2 role basic permissions
resource "aws_iam_role_policy" "ec2_basic" {
  name = "BasicEC2Access"
  role = aws_iam_role.ec2_instance_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceAttribute"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach SSM managed instance core policy (required for Systems Manager)
resource "aws_iam_role_policy_attachment" "ec2_ssm_managed_instance_core" {
  role       = aws_iam_role.ec2_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Development role - single privilege escalation path
resource "aws_iam_role" "dev_role" {
  name = "${var.lab_name}-dev-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "*"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "Development Role"
    Description = "ONLY vulnerable role - compromised user can assume this"
  }
}

resource "aws_iam_role_policy" "dev_power_user" {
name = "PowerUserAccess"
  role = aws_iam_role.dev_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # EC2 access for userdata extraction
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceAttribute",
          "ec2:GetConsoleOutput"
        ]
        Resource = "*"
      },
      {
        # S3 access for enumeration
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = "*"
      },
      {
        # Secrets Manager access to retrieve high-privileged credentials
        # Students must find SSM RCE role temporary credentials here
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecrets"
        ]
        Resource = "*"
      },
      {
        # Limited IAM for persistence
        Effect = "Allow"
        Action = [
          "iam:GetRole",
          "iam:UpdateAssumeRolePolicy",
          "iam:GetRolePolicy"
        ]
        Resource = "*"
      },
      {
        # Lambda access for persistence
        Effect = "Allow"
        Action = [
          "lambda:GetFunction",
          "lambda:UpdateFunctionConfiguration",
          "lambda:CreateFunction"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach SSM managed instance core policy to dev_role
resource "aws_iam_role_policy_attachment" "dev_role_ssm_managed_instance_core" {
  role       = aws_iam_role.dev_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# High-privilege role for SSM RCE (credentials stored in Secrets Manager)
resource "aws_iam_role" "ssm_rce_role" {
  name = "${var.lab_name}-ssm-rce-role"

  max_session_duration = 43200

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "SSM RCE Role"
    Description = "High-privilege role for SSM RCE - credentials in Secrets Manager"
  }
}

# Policy for SSM RCE execution
resource "aws_iam_role_policy" "ssm_rce_policy" {
  name = "SSMRCEAccess"
  role = aws_iam_role.ssm_rce_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole",
          "iam:ListInstanceProfilesForRole",
          "iam:ListAttachedRolePolicies",
          "iam:ListRoles",
          "iam:CreateRole",
          "iam:GetPolicy",
          "ec2:DescribeImages",
          "ssm:SendCommand",
          "ssm:GetCommandInvocation",
          "ssm:ListCommandInvocations",
          "ssm:ListCommands",
          "ssm:DescribeInstanceInformation",
          "ssm:DescribeInstanceProperties",
          "ssm:ListDocuments",
          "ssm:GetDocument",
          "ssm:StartSession",
          "ssm:TerminateSession",
          "ssm:DescribeSessions",
          "ssm:ResumeSession"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:AssociateIamInstanceProfile",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceAttribute",
          "ec2:DescribeInstanceStatus"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "iam:PassedToService" = "ssm.amazonaws.com"
          }
        }
      }
    ]
  })
}

# Instance profile for EC2 instances
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.lab_name}-ec2-profile"
  role = aws_iam_role.ec2_instance_role.name
}

resource "aws_iam_instance_profile" "dev_profile" {
  name = "${var.lab_name}-dev-profile"
  role = aws_iam_role.dev_role.name
}

