#!/bin/bash
# ==============================================================================
# Automated Deployment Script - IU Cloud Programming (Task 1)
# ==============================================================================
set -e

echo "=== Step 1: Checking Prerequisites ==="
if ! command -v terraform &> /dev/null; then
    echo "Error: Terraform is not installed. Please install Terraform first."
    exit 1
fi

echo "=== Step 2: Initializing Terraform ==="
terraform init

echo "=== Step 3: Validating Configuration ==="
terraform validate

echo "=== Step 4: Provisioning Infrastructure on AWS ==="
terraform apply -auto-approve

echo "=== Deployment Completed Successfully! ==="
echo "Access your website at:"
terraform output
