# AWS Resource Automation with Bash

## Project Overview

This project automates the creation and configuration of essential AWS resources, specifically EC2 instances, Security Groups, and S3 buckets, using Bash scripts and the AWS CLI.

It was developed as part of a DevOps automation challenge to replace manual, error-prone infrastructure provisioning with reliable, repeatable scripts.

## Prerequisites

- AWS CLI v2 installed
- Bash terminal (Linux/macOS or WSL on Windows)
- AWS account with appropriate permissions
- Basic knowledge of the terminal

## Project Structure

```text
create_ec2.sh               Automates EC2 instance creation
create_security_group.sh    Automates Security Group creation
create_s3_bucket.sh         Automates S3 Bucket creation
cleanup_resources.sh        Terminates and deletes all created resources
screenshots/                Folder containing execution screenshots
README.md                   Project documentation
```

## Setup and Configuration

### Step 1: Install AWS CLI

```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
aws --version
```

### Step 2: Configure AWS Credentials

For sandbox/event accounts with temporary credentials, export them as environment variables:

```bash
export AWS_ACCESS_KEY_ID="your_access_key"
export AWS_SECRET_ACCESS_KEY="your_secret_key"
export AWS_SESSION_TOKEN="your_session_token"
export AWS_DEFAULT_REGION="eu-west-1"
```

For personal AWS accounts:

```bash
aws configure
```

### Step 3: Verify Setup

```bash
aws sts get-caller-identity
aws configure list
```

## Scripts

### 1. create_ec2.sh

**Purpose**

Automates the creation of an EC2 instance on AWS.

**What it does**

- Creates a new EC2 key pair and saves it as a `.pem` file
- Checks if the key pair already exists before creating to avoid duplicates
- Launches a free-tier t2.micro Amazon Linux 2 instance
- Tags the instance with `Project=AutomationLab`
- Waits for the instance to enter a running state
- Prints the Instance ID and Public IP address

**Usage**

```bash
chmod +x create_ec2.sh
./create_ec2.sh
```

**Expected Output**

```text
=========================================
   Starting EC2 Instance Creation...
=========================================
[1/4] Creating key pair: automation-lab-key...
Key pair created and saved as automation-lab-key.pem
[2/4] Launching EC2 instance...
Instance launched with ID: i-0abc123def456
[3/4] Waiting for instance to enter running state...
Instance is now running!
[4/4] Fetching public IP address...
=========================================
        EC2 Instance Created!
=========================================
  Instance ID : i-0abc123def456
  Public IP   : 54.123.45.67
  Key File    : automation-lab-key.pem
  Tag         : Project=AutomationLab
  Region      : eu-west-1
=========================================
```

### 2. create_security_group.sh

**Purpose**

Automates the creation of a Security Group with SSH and HTTP access.

**What it does**

- Fetches the default VPC ID automatically
- Creates a security group named `devops-sg`
- Checks if the security group already exists before creating
- Opens port 22 for SSH access
- Opens port 80 for HTTP traffic
- Tags the security group with `Project=AutomationLab`
- Displays the security group ID and inbound rules

**Usage**

```bash
chmod +x create_security_group.sh
./create_security_group.sh
```

**Expected Output**

```text
=========================================
   Starting Security Group Creation...
=========================================
[1/4] Fetching default VPC ID...
Default VPC found: vpc-0abc123def456
[2/4] Creating security group: devops-sg...
Security group created with ID: sg-0abc123def456
[3/4] Adding inbound rules...
Port 22 (SSH) opened successfully
Port 80 (HTTP) opened successfully
[4/4] Fetching security group details...
=========================================
     Security Group Created!
=========================================
  Security Group Name : devops-sg
  Security Group ID   : sg-0abc123def456
  VPC ID              : vpc-0abc123def456
  Inbound Rules       : Port 22 (SSH), Port 80 (HTTP)
  Tag                 : Project=AutomationLab
=========================================
```

### 3. create_s3_bucket.sh

**Purpose**

Automates the creation and configuration of an S3 bucket.

**What it does**

- Generates a unique bucket name using a timestamp
- Creates the S3 bucket in `eu-west-1`
- Enables versioning on the bucket
- Applies a bucket policy granting the account owner full access
- Creates and uploads a sample `welcome.txt` file to the bucket

**Usage**

```bash
chmod +x create_s3_bucket.sh
./create_s3_bucket.sh
```

**Expected Output**

```text
=========================================
    Starting S3 Bucket Creation...
=========================================
[1/5] Creating sample file: welcome.txt...
Sample file created: welcome.txt
[2/5] Creating S3 bucket: automation-lab-bucket-1234567890...
Bucket created: automation-lab-bucket-1234567890
[3/5] Enabling versioning on bucket...
Versioning enabled successfully
[4/5] Applying bucket policy...
Bucket policy applied successfully
[5/5] Uploading welcome.txt to bucket...
File uploaded successfully
=========================================
       S3 Bucket Created!
=========================================
  Bucket Name  : automation-lab-bucket-1234567890
  Region       : eu-west-1
  Versioning   : Enabled
  Policy       : Owner Full Access
  Uploaded File: s3://automation-lab-bucket-1234567890/welcome.txt
  Tag          : Project=AutomationLab
=========================================
```

## Best Practices Applied

### Parameterization

All configurable values are defined as variables at the top of each script for easy modification.

### Error Handling

Every AWS CLI command captures its exit code and error output and responds appropriately.

### Duplicate Detection

Scripts check for existing resources before creating new ones using a try-and-handle pattern similar to try/catch in other languages.

### Least Privilege

IAM credentials are never hardcoded into scripts.

### Resource Tagging

All resources are tagged with `Project=AutomationLab` for easy identification and cleanup.

### Clean Output

Scripts provide clear step-by-step feedback with success, warning, and error indicators.

## Challenges Faced and How They Were Resolved

### Challenge 1: Sandbox Account Permission Restrictions

The company sandbox account provided for the lab had heavily restricted IAM permissions. Operations like `ec2:DescribeImages`, `ec2:RunInstances`, and `s3:CreateBucket` were all denied with `UnauthorizedOperation` errors.

**Resolution**

Investigated the sandbox restrictions and discovered that switching the AWS region to `eu-west-1` (Ireland) resolved the permission issues on the console. Applied the same fix to the CLI by setting `AWS_DEFAULT_REGION=eu-west-1`. This is a known behavior with some event-based sandbox accounts where permissions are scoped to specific regions.

### Challenge 2: Sandbox Temporary Credentials

The sandbox account provided temporary session credentials including a session token, which is different from standard AWS accounts. The region was also not provided with the credentials.

**Resolution**

Exported all credentials including the session token as environment variables and manually set the default region:

```bash
export AWS_SESSION_TOKEN="your_session_token"
export AWS_DEFAULT_REGION="eu-west-1"
```

### Challenge 3: Security Group ID Capturing Wrong Output

The `create-security-group` command was returning the full response including the ARN and tags, causing the `SG_ID` variable to be malformed and breaking the `authorize-security-group-ingress` command.

**Resolution**

Added `--query "GroupId"` to the `create-security-group` command to extract only the Security Group ID from the response:

```bash
aws ec2 create-security-group \
  --query "GroupId" \
  --output text
```

### Challenge 4: VPC Filter Syntax Error

A parameter validation error occurred on the `--filters` flag in the `describe-vpcs` command due to a syntax typo, causing the script to exit at Step 1.

**Resolution**

Fixed the filter syntax and validated the command independently in the terminal before integrating it back into the script. Also simplified the command by removing the filter entirely since the sandbox account only has one VPC available.

### Challenge 5: Duplicate Resource Errors on Re-runs

Running scripts more than once caused failures due to duplicate key pairs and security groups already existing in AWS.

**Resolution**

Implemented a try-and-handle pattern for resource creation. The script attempts to create the resource, captures the exit code and error message, and handles duplicate errors gracefully by continuing with the existing resource instead of exiting.

## AWS Region Used

All resources were provisioned in `eu-west-1` (Ireland) due to sandbox permission constraints in other regions.

## Author

Prince Asamoah  
DevOps Engineering Challenge - AmaliTech