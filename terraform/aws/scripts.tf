# Generate deployment script after infrastructure is created
resource "local_file" "deployment_script" {
  depends_on = [
    module.eks,
    aws_ecr_repository.browser_api
  ]
  
  filename = "${path.module}/../../deploy_to_eks.sh"
  file_permission = "0755"
  
  content = <<-EOT
#!/bin/bash
# BrowserStation deployment script
set -e

echo "Deploying BrowserStation to EKS cluster '${module.eks.cluster_name}'..."

# Configure kubectl
aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.region}
kubectl get nodes

# Create namespace
kubectl create namespace ray-system || echo "Namespace already exists"

# Install KubeRay operator
helm repo add kuberay https://ray-project.github.io/kuberay-helm/
helm repo update
helm install kuberay-operator kuberay/kuberay-operator --namespace ray-system --version 1.3.0 || echo "KubeRay operator already installed"
kubectl wait --for=condition=available --timeout=300s deployment/kuberay-operator -n ray-system

# Build and push Docker image
echo "Building and pushing Docker image..."
aws ecr get-login-password --region ${var.region} | docker login --username AWS --password-stdin ${data.aws_caller_identity.this.account_id}.dkr.ecr.${var.region}.amazonaws.com
docker buildx build --platform linux/amd64 -t browserstation:latest -f Dockerfile.x86_64 .
docker tag browserstation:latest ${aws_ecr_repository.browser_api.repository_url}:latest
docker push ${aws_ecr_repository.browser_api.repository_url}:latest

# Deploy RayService
echo "Deploying RayService..."
sed -i.bak 's|image: browserstation:latest|image: ${aws_ecr_repository.browser_api.repository_url}:latest|g' rayservice.yaml
kubectl apply -f rayservice.yaml

# Wait for deployment
kubectl wait --for=condition=Ready pods -l ray.io/node-type=head -n ray-system --timeout=300s || true

# Set API key if provided
if [ -n "$${BROWSERSTATION_API_KEY:-}" ]; then
  echo "API key detected. It will be used when connecting to the service."
  echo "Note: The API key is passed via environment variable to your client applications."
else
  echo "WARNING: No BROWSERSTATION_API_KEY environment variable detected."
  echo "To enable authentication, export BROWSERSTATION_API_KEY before running your applications."
fi

# Get service endpoint
echo "Service endpoint:"
kubectl get svc browser-cluster-public -n ray-system

echo "Deployment complete. Wait 2-3 minutes for LoadBalancer to be ready."
echo "Service will be available on port 8050"
EOT
}

# Generate teardown script for aggressive cleanup
resource "local_file" "teardown_script" {
  depends_on = [
    module.eks,
    aws_ecr_repository.browser_api
  ]
  
  filename = "${path.module}/../../teardown_eks.sh"
  file_permission = "0755"
  
  content = <<-EOT
#!/bin/bash
# BrowserStation teardown script
set +e

echo "Starting teardown of BrowserStation resources..."
echo "WARNING: This will forcefully delete all resources. Press Ctrl+C within 5 seconds to cancel..."
sleep 5

# Variables
CLUSTER_NAME="${module.eks.cluster_name}"
REGION="${var.region}"
VPC_ID="${module.vpc.vpc_id}"

# Configure kubectl if cluster exists
if aws eks describe-cluster --name $CLUSTER_NAME --region $REGION >/dev/null 2>&1; then
    aws eks update-kubeconfig --name $CLUSTER_NAME --region $REGION 2>/dev/null || true
    
    # Delete Kubernetes resources
    echo "Deleting Kubernetes resources..."
    kubectl delete rayservice browser-cluster -n ray-system --force --grace-period=0 2>/dev/null || true
    kubectl delete svc --all -n ray-system --force --grace-period=0 2>/dev/null || true
    kubectl delete pods --all -n ray-system --force --grace-period=0 2>/dev/null || true
    helm uninstall kuberay-operator -n ray-system 2>/dev/null || true
    kubectl delete namespace ray-system --force --grace-period=0 2>/dev/null || true
fi

# Delete AWS LoadBalancers
echo "Cleaning up AWS LoadBalancers..."
LOAD_BALANCERS=$(aws elb describe-load-balancers --region $REGION --query "LoadBalancerDescriptions[?VPCId=='$VPC_ID'].LoadBalancerName" --output text 2>/dev/null || true)
for lb in $LOAD_BALANCERS; do
    aws elb delete-load-balancer --load-balancer-name $lb --region $REGION 2>/dev/null || true
done

LB_ARNS=$(aws elbv2 describe-load-balancers --region $REGION --query "LoadBalancers[?VpcId=='$VPC_ID'].LoadBalancerArn" --output text 2>/dev/null || true)
for lb_arn in $LB_ARNS; do
    aws elbv2 delete-load-balancer --load-balancer-arn $lb_arn --region $REGION 2>/dev/null || true
done

sleep 30

# Release Elastic IPs
echo "Releasing Elastic IPs..."
UNASSOCIATED_EIPS=$(aws ec2 describe-addresses --region $REGION --query "Addresses[?AssociationId==null].AllocationId" --output text 2>/dev/null || true)
for eip in $UNASSOCIATED_EIPS; do
    aws ec2 release-address --allocation-id $eip --region $REGION 2>/dev/null || true
done

# Delete Network Interfaces
echo "Cleaning up Network Interfaces..."
ENIS=$(aws ec2 describe-network-interfaces --region $REGION --filters "Name=vpc-id,Values=$VPC_ID" --query "NetworkInterfaces[?Status=='available'].NetworkInterfaceId" --output text 2>/dev/null || true)
for eni in $ENIS; do
    aws ec2 delete-network-interface --network-interface-id $eni --region $REGION 2>/dev/null || true
done

# Delete ECR images
echo "Cleaning up ECR repository..."
# Note: ECR repository has force_delete = true, so terraform destroy will handle this

# Run terraform destroy
echo "Running terraform destroy..."
cd terraform/aws/
terraform destroy -auto-approve

if [ $? -eq 0 ]; then
    echo "Terraform destroy completed successfully."
else
    echo "Terraform destroy failed. Check AWS Console for remaining resources."
fi
EOT
}

# Outputs
output "deployment_script_created" {
  value = "Deployment script created: ./deploy_to_eks.sh"
  depends_on = [local_file.deployment_script]
}

output "teardown_script_created" {
  value = "Teardown script created: ./teardown_eks.sh"
  depends_on = [local_file.teardown_script]
}