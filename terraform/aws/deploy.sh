#!/bin/bash

# Deploy script for BrowserStation on AWS
# This script deploys both infrastructure (01-infra) and Kubernetes resources (02-k8s)

set -e  # Exit on error

# Default values
API_KEY=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --api-key)
            API_KEY="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [--api-key YOUR_API_KEY]"
            echo ""
            echo "Options:"
            echo "  --api-key    Set the BrowserStation API key (default: empty - no auth)"
            echo "  -h, --help   Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

echo "🚀 Starting BrowserStation deployment..."
if [ -n "$API_KEY" ]; then
    echo "   Using API key: ${API_KEY:0:8}..."
else
    echo "   No API key provided - authentication disabled"
fi
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if we're in the right directory
if [ ! -d "01-infra" ] || [ ! -d "02-k8s" ]; then
    print_error "This script must be run from the terraform/aws directory"
    exit 1
fi

# Deploy 01-infra
print_status "Deploying infrastructure (01-infra)..."
cd 01-infra

print_status "Running terraform init..."
terraform init

print_status "Running terraform apply..."
if terraform apply -auto-approve; then
    print_status "Infrastructure deployment completed successfully!"
else
    print_error "Infrastructure deployment failed!"
    exit 1
fi

# Get outputs for 02-k8s
print_status "Retrieving infrastructure outputs..."
cd ..

# Deploy 02-k8s
print_status "Deploying Kubernetes resources (02-k8s)..."
cd 02-k8s

print_status "Running terraform init..."
terraform init

print_status "Running terraform apply..."
if [ -n "$API_KEY" ]; then
    terraform apply -var="browserstation_api_key=$API_KEY" -auto-approve
else
    terraform apply -auto-approve
fi

if [ $? -eq 0 ]; then
    print_status "Kubernetes resources deployment completed successfully!"
else
    print_error "Kubernetes resources deployment failed!"
    exit 1
fi

# Get the endpoint
ENDPOINT=$(terraform output -raw browserstation_endpoint 2>/dev/null || echo "")

cd ..

# Summary
echo ""
print_status "🎉 Deployment completed successfully!"
echo ""
echo "BrowserStation is now running at:"
echo "  http://${ENDPOINT}:8050"
echo ""
echo "To test the deployment:"
echo "  curl -X GET http://${ENDPOINT}:8050/"
echo ""
echo "To create a browser:"
if [ -n "$API_KEY" ]; then
    echo "  curl -X POST http://${ENDPOINT}:8050/browsers \\"
    echo "    -H 'X-API-Key: $API_KEY' \\"
    echo "    -H 'Content-Type: application/json'"
else
    echo "  curl -X POST http://${ENDPOINT}:8050/browsers \\"
    echo "    -H 'Content-Type: application/json'"
    echo ""
    echo "  Note: No API key set - authentication is disabled"
fi