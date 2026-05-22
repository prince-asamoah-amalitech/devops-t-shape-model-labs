#!/bin/bash

# Purpose: Terminate and delete all resources created by the AutomationLab scripts

# -- Configuration Variables --
REGION="eu-west-1"
TAG_KEY="Project"
TAG_VALUE="AutomationLab"
KEY_NAME="automation-lab-key"
KEY_FILE="automation-lab-key.pem"
SG_NAME="devops-sg"

echo "======================================="
echo "   Starting Resource Cleanup...  "
echo "======================================="
echo "WARNING: This will delete all resources"
echo "tagged with $TAG_KEY=$TAG_VALUE"
echo "======================================="

# -- Confirm Before Proceeding --
read -p "Are you sure you want to continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Cleanup cancelled."
    exit 0
fi

# 1. Terminate EC2 Instances
echo ""
echo "[1/5] Finding EC2 instances tagged with $TAG_KEY=$TAG_VALUE..."

INSTANCE_IDS=$(aws ec2 describe-instances \
    --region "$REGION" \
    --filters "Name=tag:$TAG_KEY,Values=$TAG_VALUE" \
    "Name=instance-state-name,Values=running,stopped,pending" \
    --query "Reservations[*].Instances[*].InstanceId" \
    --output text 2>&1)

if [ -z "$INSTANCE_IDS" ] || echo "$INSTANCE_IDS" | grep -q "ERROR"; then
   echo "No EC2 instances found with tag $TAG_KEY=$TAG_VALUE"
else
   echo "Found instances: $INSTANCE_IDS"
   echo "Terminating instances..."

   TERMINATE_OUTPUT=$(aws ec2 terminate-instances \
       --instance-ids $INSTANCE_IDS \
       --output text 2>%1)

   if [ $? -eq 0 ]; then
        echo "EC2 instances termination initiated"
        echo "Waiting for instances to terminate..."
        aws ec2 wait instance-terminated --instance-ids $INSTANCE_IDS
        echo "EC2 instances terminated successfully"
   else
        echo "Failed to terminate instances. Error: $TERMINATE_OUTPUT"
   fi
fi

# 2. Delete Key Pair
echo ""
echo "[2/5] Deleting key pair: $KEY_NAME..."

KEY_OUTPUT=$(aws ec2 delete-key-pair \
    --key-name "$KEY_NAME" 2>&1)

if [ $? -eq 0 ]; then
    echo "Key pair '$KEY_FILE' deleted from AWS"

    # Also delete local .pem file if it exists
    if [ -f "$KEY_FILE" ]; then
        rm -f "$KEY_FILE"
        echo "Local key file '$KEY_FILE' deleted"
    fi
elif echo "$KEY_OUTPUT" | grep -q "InvalidKeyPair.NotFound"; then
    echo "Key pair '$KEY_NAME' not found - may have already been deleted"
else
    echo "Failed to delete key pair. Error $KEY_OUTPUT"
fi

# 3. Delete Security Group
echo ""
echo "[3/5] Deleting security group: $SG_NAME..."

# Get the security group ID first
SG_ID=$(aws ec2 describe-security-groups \
   --filters "Name=group-name,Values=$SG_NAME" \
   --query "SecurityGroups[0].GroupId" \
   --output text 2>&1)

if [ -z "$SG_ID" ] || [ "$SG_ID" == "None" ] || echo "$SG_ID" | grep -q "ERROR"; then
    echo "Security group '$SG_NAME' not found - may have already been deleted"
else
    echo "Found security group: $SG_ID"

    SG_OUTPUT=$(aws ec2 delete-security-group \
    --group-id "$SG_ID" 2>&1)

   if [ $? -eq 0 ]; then
       echo "Security group '$SG_NAME' deleted successfully"
   else
       echo "Failed to delete security group. Error: $SG_OUTPUT"
       echo "Note: Security groups cannot be deleted while still attached to an instance"
   fi
fi

# 4. Find and Empty S3 Buckets
echo ""
echo "[4/5] Finding S3 buckets with prefix 'automation-lab-bucket'..."

BUCKETS=$(aws s3api list-buckets \
    --query "Buckets[?starts_with(Name, 'automation-lab')].Name" \
    --output text 2>&1)

if [ -z "$BUCKETS" ] || echo "$BUCKETS" | grep -q "Error"; then
    echo "No matching S3 buckets found"
else
    for BUCKET in $BUCKETS; do
        echo "Processing bucket: $BUCKET"

        # Remove all objects including versioned objects first
        echo "  Removing all object from $BUCKET..."
        aws s3 rm "s3://$BUCKET" --recursive 2>/dev/null

        #Delete all versions if versioning was enabled
        echo "  Removing all versions from $BUCKET..."

        VERSIONS=$(aws s3api list-object-versions \
           --bucket "$BUCKET" \
           --query "{Objects: Versions[].{Key:Key,VersionId:VersionId}}" \
           --output json 2>/dev/null)

        MARKERS=$(aws s3api list-object-versions \
           --bucket "$BUCKET" \
           --query "{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}" \
           --output json 2>/dev/null)

        # Delete all versions
        if [ "$VERSIONS" != "null" ] && [ -n "$VERSIONS" ]; then
            aws s3api delete-objects \
                --bucket "$BUCKET" \
                --delete "$VERSIONS" 2>/dev/null
        fi

        #Delete all markers
        if [ "$MARKERS" != "null" ] && [ -n "$MARKERS" ]; then
             aws s3api delete-objects \
                 --bucket "$BUCKET" \
                 --delete "$MARKERS" 2>/dev/null
             echo "Delete markers deleted"
        fi

        # Now delete the bucket
        BUCKET_OUTPUT=$(aws s3api delete-bucket \
            --bucket "$BUCKET" \
            --region "$REGION" 2>&1)

        if [ $? -eq 0 ]; then
            echo "Bucket '$BUCKET' deleted successfully"
        else
            echo "Failed to delete bucket '$BUCKET'. Error: $BUCKET_OUTPUT"
        fi
    done
fi

# 5. Final Verification
echo ""
echo "[5/5] Verifying cleanup..."

# Check for any remaining instances
REMAINING=$(aws ec2 describe-instances \
    --filters "Name=tag:$TAG_KEY,Values=$TAG_VALUE" \
              "Name=instance-state-name,Values=running,stopped,pending" \
    --query "Reservations[*].Instances[*].InstanceId" \
    --output text 2>/dev/null)

if [ -z "$REMAINING" ]; then
    echo "No remaining EC2 instances found"
else
    echo "Some instances may still exist: $REMAINING"
fi


# --- Final Summary ---
echo ""
echo "=================================="
echo "     Cleanup Complete!            "
echo "=================================="
echo " EC2 Instances: Terminated "
echo " Key Pair: Deleted "
echo " Security Group: Deleted "
echo " S3 Buckets: Emptied and Deleted "
echo " Local Key File: Deleted "
echo "=================================="