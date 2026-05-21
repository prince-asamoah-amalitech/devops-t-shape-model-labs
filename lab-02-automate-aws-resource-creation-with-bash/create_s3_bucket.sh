#!/bin/bash

# Purpose: Automate S3 Bucket Creation

# Configuration Variables
BUCKET_NAME="automation-lab-bucket-$(date +%s)" # Unique name using timestamp
REGION="eu-west-1"
SAMPLE_FILE="welcome.txt"

echo "-- Starting S3 Bucket Creation... --"

# 1. Create sample file to upload
echo "[1/5] Creating sample file: $SAMPLE_FILE..."

cat > "$SAMPLE_FILE" << EOF
Welcome to AutomationLab!
=========================
This file was uploaded automatically by create_s3_bucket.sh
Bucket: $BUCKET_NAME
Region: $REGION
Date: $(date)
Project: AutomationLab
EOF

echo " Sample file created: $SAMPLE_FILE "

# 2. Create S3 Bucket
echo "[2/5] Creating S3 Bucket: $BUCKET_NAME..."

BUCKET_OUTPUT=$(aws s3api create-bucket \
    --bucket "$BUCKET_NAME" \
    --region "$REGION" \
    --create-bucket-configuration LocationConstraint="$REGION" \
    --output text 2>&1)

EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo "Bucket created: $BUCKET_NAME"
elif echo "$BUCKET_OUPUT" | grep -q "BucketAlreadyOwnedByYou"; then
    echo "Bucket already exists and is owned by you - continuing..."
else
    echo "Failed to create bucket. Error: $BUCKET_OUTPUT"
    exit 1
fi


# 3. Enable Versioning
echo "[3/5] Enabling versioning on bucket..."

VERSIONING_OUTPUT=$(aws s3api put-bucket-versioning \
    --bucket "$BUCKET_NAME" \
    --versioning-configuration Status=Enabled 2>&1)

if [ $? -eq 0 ]; then
    echo "Versioning enabled successfully"
else
    echo "Failed to enable versioning. Error : $VERSIONING_OUTPUT"
    exit 1
fi

# 4. Set Bucket Policy
echo "[4/5] Applying bucket policy"

# Create the bucket policy
POLICY=$(cat << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowOwnerFullAccess",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):root"
      },
      "Action": "s3:*",
      "Resource": [
        "arn:aws:s3:::$BUCKET_NAME",
        "arn:aws:s3:::$BUCKET_NAME/*"
      ]
    }
  ]
}
EOF
)

POLICY_OUPUT=$(aws s3api put-bucket-policy \
    --bucket "$BUCKET_NAME" \
    --policy "$POLICY" 2>&1)

if [ $? -eq 0 ]; then
    echo "Bucket policy applied successfully"
else
    echo "Failed to apply bucket policy. Error: $POLICY_OUTPUT"
    exit 1
fi

# Upload Sample File
echo "[5/5] Uploading $SAMPLE_FILE to bucket..."

UPLOAD_OUTPUT=$(aws s3 cp "$SAMPLE_FILE" "s3://$BUCKET_NAME/$SAMPLE_FILE" 2>&1)

if [ $? -eq 0 ]; then
    echo "File uploaded successfully"
else
    echo "Failed to upload file. Error: $UPLOAD_OUTPUT"
    exit 1
fi

# Final Summary
echo ""
echo "=============================="
echo "    S3 Bucket Created! 🎉"
echo "=============================="
echo "  Bucket Name : $BUCKET_NAME  "
echo "  Region : $REGION "
echo "  Versioning: Enabled "
echo "  Uploaded File: s3://$BUCKET_NAME/$SAMPLE_FILE "
echo "  Tag : Projecdt=AutomationLab "
echo "=============================="
