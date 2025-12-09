## Description
This Terraform configuration creates a vulnerable AWS environment for educational purposes, designed to teach students how to identify and exploit common AWS misconfigurations using the PACU (Privilege Escalation in AWS) framework.

## Lab Overview

This lab simulates a compromised AWS environment where students will:
- Start with compromised IAM credentials
- Perform enumeration across IAM, EC2, S3, STS, and CloudTrail
- Identify privilege escalation paths through role chaining
- Exploit CloudTrail blind spots
- Practice data exfiltration techniques
- Establish persistence mechanisms


## Lab Architecture 
```mermaid
graph TB
    subgraph "AWS Account"
        subgraph "Network Layer"
            VPC[VPC<br/>10.0.0.0/16]
            PubSub[Public Subnet<br/>10.0.1.0/24]
            PrivSub1[Private Subnet 1<br/>10.0.2.0/24]
            PrivSub2[Private Subnet 2<br/>10.0.3.0/24]
            IGW[Internet Gateway]
        end
        
        subgraph "Compute Resources"
            WebServer[Web Server<br/>EC2 Instance<br/>Instance Profile: ec2-instance-role<br/>Public IP]
            DevServer[Dev Server<br/>EC2 Instance<br/>Instance Profile: dev-profile<br/>Private IP]
            DataServer[Data Server<br/>EC2 Instance<br/>No Profile<br/>Private IP]
            Lambda[Lambda Function<br/>backup-function<br/>Role: lambda-service-role]
        end
        
        subgraph "IAM Resources"
            CompUser[Compromised User<br/>Initial Entry Point<br/>Read-Only Access]
            EC2Role[EC2 Instance Role<br/>Can Assume: lambda, dev, admin]
            DevRole[Dev Role<br/>Trust: Anyone<br/>Power User Access]
            AdminRole[Admin Role<br/>Full Access]
            LambdaRole[Lambda Service Role<br/>Trust: Anyone<br/>Full Access]
        end
        
        subgraph "Storage Resources"
            PublicBucket[(Public S3 Bucket<br/>Public Read Access)]
            PrivateBucket[(Private S3 Bucket<br/>Authenticated Users Access)]
            SecretsBucket[(Secrets S3 Bucket<br/>Role-Based Access)]
            BackupBucket[(Backup S3 Bucket<br/>us-west-2 Region)]
        end
        
        subgraph "Monitoring"
            CloudTrail[CloudTrail<br/>Single Region<br/>No Global Events]
        end
        
        subgraph "Secrets"
            SecretsManager[Secrets Manager<br/>Database Credentials<br/>API Keys]
        end
    end
    
    Internet[Internet]
    Student[Student Attacker<br/>Compromised Credentials]
    
    Internet -->|HTTP/HTTPS/SSH| IGW
    IGW --> VPC
    VPC --> PubSub
    VPC --> PrivSub1
    VPC --> PrivSub2
    
    PubSub --> WebServer
    PrivSub1 --> DevServer
    PrivSub2 --> DataServer
    
    Student -->|Access Key| CompUser
    CompUser -->|Assume Role| DevRole
    DevRole -->|Assume Role| AdminRole
    CompUser -->|Enumeration| EC2Role
    CompUser -->|Enumeration| LambdaRole
    
    WebServer -.->|Instance Profile| EC2Role
    DevServer -.->|Instance Profile| DevRole
    Lambda -.->|Execution Role| LambdaRole
    
    EC2Role -->|Assume Role| DevRole
    EC2Role -->|Assume Role| AdminRole
    EC2Role -->|Assume Role| LambdaRole
    
    CompUser -->|List/Read| PublicBucket
    CompUser -->|List/Read| PrivateBucket
    DevRole -->|Full Access| SecretsBucket
    AdminRole -->|Full Access| BackupBucket
    
    CloudTrail -->|Logs API Calls| S3Logs[S3 Log Bucket]
    
    style CompUser fill:#ff6b6b
    style DevRole fill:#ffa500
    style AdminRole fill:#ff0000
    style PublicBucket fill:#ffeb3b
    style PrivateBucket fill:#ff9800
    style SecretsBucket fill:#f44336
    style CloudTrail fill:#9e9e9e
```




## Installation

### 1. Clone and Initialize

```bash
# Navigate to the lab directory
cd PACULabs

# Initialize Terraform
terraform init
```

### 2. Review Configuration

Review `variables.tf` to customize:
- `aws_region`: Primary region for resources (default: us-east-1)
- `backup_region`: Region for exfiltration demo (default: us-west-2)
- `student_password`: Password for compromised user
- `lab_name`: Prefix for all resources

### 3. Deploy the Lab Environment

```bash
# Plan the deployment
terraform plan

# Apply the configuration
terraform apply
```

**Important**: The output will include sensitive credentials. Save these securely!

### 4. Retrieve Lab Credentials

After deployment, extract the credentials:

```bash
# Get compromised user credentials in JSON format (shows sensitive values)
terraform output -json compromised_user_credentials

# Save credentials to a file (Linux/Mac)
terraform output -json compromised_user_credentials > credentials.json

# View the saved credentials
cat credentials.json

# Pretty-print JSON for better readability (requires jq)
terraform output -json compromised_user_credentials | jq .

# Or without jq (using Python)
terraform output -json compromised_user_credentials | python3 -m json.tool
```

**Example Output**:
The `credentials.json` file will contain:
```json
{
  "access_key_id": "AKIAIOSFODNN7EXAMPLE",
  "secret_access_key": "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
}
```

**Note**: Since credentials are marked as sensitive, use `-json` flag or `-raw` flag to display them, as regular `terraform output` will hide sensitive values.







## DISCLAIMER

**This lab environment is for EDUCATIONAL PURPOSES ONLY.** It contains intentional security misconfigurations and should NEVER be deployed to production or any environment containing real data. Use only in isolated AWS accounts dedicated to security training.
