# ========================================
# EC2 Instances with Various Vulnerabilities
# ========================================

# Public web server with compromised instance profile
resource "aws_instance" "web_server" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    echo "<h1>Web Server - Check Instance Profile!</h1>" > /var/www/html/index.html
    
    # Create a file with hints
    mkdir -p /tmp/lab
    echo "This instance has an IAM instance profile: ${aws_iam_instance_profile.ec2_profile.name}" > /tmp/lab/hint.txt
    echo "Try: aws sts get-caller-identity (if AWS CLI is configured)" >> /tmp/lab/hint.txt
  EOF

  tags = {
    Name        = "${var.lab_name}-web-server"
    Description = "Public web server with instance profile"
    Environment = "Production"
  }
}

# Private development server with dev role
resource "aws_instance" "dev_server" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.private_subnet_1.id
  vpc_security_group_ids = [aws_security_group.private_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.dev_profile.name

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    
    # Create development files with sensitive data
    mkdir -p /home/ec2-user/dev
    echo "dev_password=SuperSecret123!" > /home/ec2-user/dev/.env
    echo "api_key=AKIAIOSFODNN7EXAMPLE" >> /home/ec2-user/dev/.env
    chmod 644 /home/ec2-user/dev/.env  # VULNERABILITY: World readable
    
    # Create hint file
    echo "This instance has the dev role: ${aws_iam_role.dev_role.name}" > /tmp/lab/hint.txt
    echo "The dev role can assume the admin role!" >> /tmp/lab/hint.txt
  EOF

  tags = {
    Name        = "${var.lab_name}-dev-server"
    Description = "Private dev server with privileged role"
    Environment = "Development"
  }
}

# Private data server (may have access keys or secrets)
resource "aws_instance" "data_server" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.private_subnet_2.id
  vpc_security_group_ids = [aws_security_group.private_sg.id]

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    
    # Simulate leaked credentials in instance metadata or files
    mkdir -p /opt/backup
    cat > /opt/backup/config.json <<EOL
    {
      "database": {
        "host": "internal-db.example.com",
        "credentials": {
          "username": "admin",
          "password": "P@ssw0rd123"
        }
      },
      "aws": {
        "access_key": "${aws_iam_access_key.lab_user.id}",
        "secret_key": "${aws_iam_access_key.lab_user.secret}",
        "region": "${var.aws_region}"
      }
    }
    EOL
    
    chmod 644 /opt/backup/config.json  # VULNERABILITY: World readable
  EOF

  tags = {
    Name        = "${var.lab_name}-data-server"
    Description = "Data server with potentially leaked credentials"
    Environment = "Production"
    Sensitivity = "High"
  }
}

