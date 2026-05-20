#!/bin/bash

# Purpose: Automate EC2 instance creation

# --- Configuration Variables ---
KEY_NAME="automation-lab-key"
INSTANCE_TYPE="t2.micro"
AMI_ID="ami-076a3d6391b613606"   # Amazon Linux 2 - eu-west-1 (Ireland)
REGION="eu-west-1"
TAG="Project=Automationlab"
KEY_FILE="${KEY_NAME}.pem"

echo "--- Starting EC2 Instance Creation... ---"

# 1. Create Key Pair
echo "[1/4] Creating key pair: $KEY_NAME"

# Attempt to create key pair and capture output error
aws ec2 create-key-pair \
    --key-name "$KEY_NAME" \
    --query "KeyMaterial" \
    --output text > "$KEY_FILE"

if [ $? -eq 0 ]; then
    # Save the key material to file
    chmod 400 "$KEY_FILE"
    echo "Key pair created and saved as $KEY_FILE"
else
    echo "Failed to create key pair. Exiting..."
    exit 1
fi

# 2. Create EC2 Instance
echo "[2/4] Launching EC2 instance..."

INSTANCE_ID=$(aws ec2 run-instances \
    --image-id "$AMI_ID" \
    --instance-type "$INSTANCE_TYPE" \
    --key-name "$KEY_NAME" \
    --region "$REGION" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Project,Value=AutomationLab}]" \
    --query "Instances[0].InstanceId" \
    --output text)

if [ $? -eq 0 ] && [ -n "$INSTANCE_ID" ]; then
    echo "Instance launched with ID: $INSTANCE_ID"
else
    echo "Failed to launch instance. Exiting..."
    exit 1
fi

# Wait for Instance to be Running
echo "[3/4] Waiting for instance to enter running state..."

aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"
echo "Instance is now running!"

# Get Public IP
echo "[4/4] Fetching public IP address..."

PUBLIC_IP=$(aws ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --query "Reservations[0].Instances[0].PublicIpAddress" \
    --output text)

# Final Summary
echo ""
echo "============================"
echo "  EC2 Instance Created! 🎉  "
echo "============================"
echo " Instance ID : $INSTANCE_ID "
echo " Public IP : $PUBLIC_IP "
echo " Key File : $KEY_FILE "
echo " Tag : $TAG "
echo " Region : $REGION "
echo "============================"