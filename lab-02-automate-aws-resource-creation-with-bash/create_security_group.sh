#!/bin/bash

# =============================================
# Script: create_security_group.sh
# Purpose: Automate Security Group creation
# =============================================

# --- Configuration Variables ---
SG_NAME="devops-sg"
SG_DESCRIPTION="DevOps Security Group - AutomationLab"
REGION="eu-west-1"

echo "========================================="
echo "   Starting Security Group Creation..."
echo "========================================="

# --- Step 1: Get Default VPC ID ---
echo "[1/4] Fetching default VPC ID..."

VPC_ID=$(aws ec2 describe-vpcs \
  --filters "Name=isDefault,Values=true" \
  --query "Vpcs[0].VpcId" \
  --output text)

if [ $? -eq 0 ] && [ -n "$VPC_ID" ]; then
  echo "✅ Default VPC found: $VPC_ID"
else
  echo "❌ Failed to get VPC ID. Exiting."
  exit 1
fi

# --- Step 2: Create Security Group ---
echo "[2/4] Creating security group: $SG_NAME..."

SG_OUTPUT=$(aws ec2 create-security-group \
  --group-name "$SG_NAME" \
  --description "$SG_DESCRIPTION" \
   --vpc-id "$VPC_ID" \
  --tag-specifications "ResourceType=security-group,Tags=[{Key=Project,Value=AutomationLab}]" \
  --query "GroupdId" \
  --output text 2>&1)

EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
  SG_ID="$SG_OUTPUT"
  echo "✅ Security group created with ID: $SG_ID"

elif echo "$SG_OUTPUT" | grep -q "InvalidGroup.Duplicate"; then
  echo "⚠️  Security group '$SG_NAME' already exists — fetching its ID..."
  SG_ID=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=$SG_NAME" \
    --query "SecurityGroups[0].GroupId" \
    --output text)
  echo "✅ Using existing security group: $SG_ID"

else
  echo "❌ Failed to create security group. Error: $SG_OUTPUT"
  exit 1
fi

# --- Step 3: Add Inbound Rules ---
echo "[3/4] Adding inbound rules..."

# Open Port 22 for SSH
SSH_OUTPUT=$(aws ec2 authorize-security-group-ingress \
  --group-id "$SG_ID" \
  --protocol tcp \
  --port 22 \
  --cidr 0.0.0.0/0 2>&1)

if [ $? -eq 0 ]; then
  echo "✅ Port 22 (SSH) opened successfully"
elif echo "$SSH_OUTPUT" | grep -q "InvalidPermission.Duplicate"; then
  echo "⚠️  Port 22 (SSH) rule already exists — skipping..."
else
  echo "❌ Failed to open port 22. Error: $SSH_OUTPUT"
  exit 1
fi

# Open Port 80 for HTTP
HTTP_OUTPUT=$(aws ec2 authorize-security-group-ingress \
  --group-id "$SG_ID" \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0 2>&1)

if [ $? -eq 0 ]; then
  echo "✅ Port 80 (HTTP) opened successfully"
elif echo "$HTTP_OUTPUT" | grep -q "InvalidPermission.Duplicate"; then
  echo "⚠️  Port 80 (HTTP) rule already exists — skipping..."
else
  echo "❌ Failed to open port 80. Error: $HTTP_OUTPUT"
  exit 1
fi

# --- Step 4: Display Security Group Details ---
echo "[4/4] Fetching security group details..."

aws ec2 describe-security-groups \
  --group-ids "$SG_ID" \
  --query "SecurityGroups[0].{ID:GroupId,Name:GroupName,Rules:IpPermissions}" \
  --output table

# --- Final Summary ---
echo ""
echo "========================================="
echo "     Security Group Created! 🎉"
echo "========================================="
echo "  Security Group Name : $SG_NAME"
echo "  Security Group ID   : $SG_ID"
echo "  VPC ID              : $VPC_ID"
echo "  Inbound Rules       : Port 22 (SSH), Port 80 (HTTP)"
echo "  Tag                 : Project=AutomationLab"
echo "========================================="