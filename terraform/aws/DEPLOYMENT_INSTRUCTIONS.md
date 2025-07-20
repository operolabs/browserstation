# BrowserStation AWS Deployment Instructions

## Prerequisites
- AWS CLI configured with credentials
- Docker installed and running
- Terraform >= 1.6
- kubectl installed

## Two-Stage Architecture

The deployment is split into two stages to avoid circular dependencies:
- **01-infra**: VPC, EKS cluster, node groups, ECR repository
- **02-k8s**: Kubernetes resources (Helm charts, services, etc.)

## Deployment Steps

### 1. Deploy Infrastructure (Stage 1)
```bash
cd terraform/aws/01-infra
terraform init
terraform apply -auto-approve
```

### 2. Deploy Kubernetes Resources (Stage 2)
```bash
cd ../02-k8s
terraform init

# Without API key
terraform apply -auto-approve

# With API key
terraform apply -var="browserstation_api_key=your-secret-key" -auto-approve
```

### 3. Get Load Balancer Endpoint
```bash
terraform output -raw browserstation_endpoint
```

## Testing

```bash
# Set the endpoint
ENDPOINT=$(terraform output -raw browserstation_endpoint)

# Health check
curl http://$ENDPOINT:8050/

# If deployed with API key
curl -X POST http://$ENDPOINT:8050/browsers \
  -H "X-API-Key: your-secret-key" \
  -H "Content-Type: application/json"

# If deployed without API key
curl -X POST http://$ENDPOINT:8050/browsers
```

## Cleanup (IMPORTANT: Reverse Order)

**Must destroy in reverse order to avoid errors:**

```bash
# First destroy Kubernetes resources
cd terraform/aws/02-k8s
terraform destroy -auto-approve

# Then destroy infrastructure
cd ../01-infra
terraform destroy -auto-approve
```

## Quick Commands

### Full Deployment with API Key
```bash
cd terraform/aws/01-infra && terraform init && terraform apply -auto-approve
cd ../02-k8s && terraform init && terraform apply -var="browserstation_api_key=my-key" -auto-approve
```

### Full Cleanup
```bash
cd terraform/aws/02-k8s && terraform destroy -auto-approve
cd ../01-infra && terraform destroy -auto-approve
```

## Benefits of Two-Stage Pattern

1. **No circular dependencies**: Kubernetes providers in 02-k8s read cluster info from 01-infra outputs
2. **Clean destruction**: Kubernetes resources are destroyed before the cluster
3. **No more "Cluster has nodegroups attached" errors**
4. **Modular**: Can update Kubernetes resources without touching infrastructure

## Troubleshooting

### If destroy fails
The two-stage pattern should prevent destroy failures. If issues occur:
1. Always destroy 02-k8s before 01-infra
2. Check for lingering LoadBalancers: `kubectl get svc -A`
3. Manually delete stuck resources if needed