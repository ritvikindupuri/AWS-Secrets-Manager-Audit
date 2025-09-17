#!/bin/bash

# A script to audit AWS Secrets Manager for common misconfigurations.
# It enumerates all secrets and checks their metadata and policies.
#
# Prerequisites: aws-cli, jq (JSON processor)

echo "Starting AWS Secrets Manager Audit..."
echo "-------------------------------------"

# Get the AWS region from configuration, or default to us-east-1
AWS_REGION=$(aws configure get region)
AWS_REGION=${AWS_REGION:-us-east-1}
echo "Auditing in region: $AWS_REGION"
echo ""

# Step 1: List all secrets in the account
echo "### Finding all secrets... ###"
SECRETS_LIST=$(aws secretsmanager list-secrets --output json)

if [ -z "$SECRETS_LIST" ]; then
    echo "No secrets found or an error occurred."
    exit 1
fi

echo "Found the following secrets:"
echo "$SECRETS_LIST" | jq -r '.SecretList[] | .Name'
echo ""

# Step 2: Loop through each secret and describe its details
echo "### Analyzing each secret individually... ###"
echo "$SECRETS_LIST" | jq -c '.SecretList[]' | while read -r secret; do
    SECRET_ARN=$(echo "$secret" | jq -r '.ARN')
    SECRET_NAME=$(echo "$secret" | jq -r '.Name')

    echo "-------------------------------------"
    echo "Analyzing Secret: $SECRET_NAME"
    echo "ARN: $SECRET_ARN"
    echo ""

    # Get detailed metadata for the secret
    echo "--> Describing secret metadata:"
    aws secretsmanager describe-secret --secret-id "$SECRET_ARN" --output json | jq '.'
    echo ""

    # Check for a resource-based policy
    echo "--> Checking for a resource policy:"
    POLICY=$(aws secretsmanager get-resource-policy --secret-id "$SECRET_ARN" --output json 2>/dev/null)
    
    if [ $? -eq 0 ] && [ -n "$POLICY" ]; then
        echo "!! Found a resource policy attached:"
        echo "$POLICY" | jq '.'
    else
        echo "No resource policy attached."
    fi
    echo ""
done

echo "Audit Complete."
