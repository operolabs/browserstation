# BrowserStation AWS Deployment Instructions

## Prerequisites
- AWS CLI configured with credentials
- Docker installed and running
- Terraform >= 1.6
- kubectl installed

## Deployment Steps

### 1. Initialize Terraform
```bash
cd terraform/aws
terraform init
```

### 2. Configure Variables (Optional)
Review and modify `terraform.tfvars` if needed:
- `cluster_name`: EKS cluster name (default: browserstation)
- `region`: AWS region (default: us-east-1)
- `worker_node_config`: Min/max/desired worker nodes

### 3. Deploy Infrastructure
Due to Terraform provider initialization requirements, deployment requires two phases:

#### Phase 1: Create EKS Cluster and Infrastructure
```bash
terraform apply -target=module.vpc -target=module.eks -target=aws_ecr_repository.browser_api -auto-approve
```

#### Phase 2: Deploy Kubernetes Resources
```bash
terraform apply -auto-approve
```

This will:
1. Create VPC and networking components
2. Deploy EKS cluster with node groups
3. Create ECR repository
4. Build and push Docker image
5. Install KubeRay operator
6. Deploy BrowserStation RayService

### 4. Get Load Balancer Endpoint
After deployment completes, wait a few minutes for the LoadBalancer to provision, then:

```bash
# Get the service endpoint
kubectl get svc -n ray-system browser-cluster-public -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

### 5. Test the Deployment
```bash
# Set the endpoint
ENDPOINT=$(kubectl get svc -n ray-system browser-cluster-public -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Health check
curl http://$ENDPOINT:8050/

# Create a browser
curl -X POST http://$ENDPOINT:8050/browsers

# List browsers
curl http://$ENDPOINT:8050/browsers
```

### 6. WebSocket Connection Example
```python
import asyncio
import websockets
import json

async def test_websocket():
    endpoint = "YOUR_ENDPOINT_HERE"
    browser_id = "YOUR_BROWSER_ID"
    
    # Connect to Chrome DevTools Protocol
    uri = f"ws://{endpoint}:8050/ws/browsers/{browser_id}/devtools/browser/page"
    
    async with websockets.connect(uri) as websocket:
        # Send a CDP command
        await websocket.send(json.dumps({
            "id": 1,
            "method": "Target.getTargets",
            "params": {}
        }))
        
        # Receive response
        response = await websocket.recv()
        print(json.loads(response))

asyncio.run(test_websocket())
```

## Monitoring

### View Ray Dashboard
```bash
# Port-forward Ray dashboard
kubectl port-forward -n ray-system svc/browser-cluster-head-svc 8265:8265

# Access at http://localhost:8265
```

### View Logs
```bash
# Ray head logs
kubectl logs -n ray-system -l ray.io/node-type=head -c ray-head

# Worker logs
kubectl logs -n ray-system -l ray.io/node-type=worker -c ray-worker
```

## Cleanup

### Complete Teardown
```bash
terraform destroy -auto-approve
```

This will remove:
- EKS cluster and all Kubernetes resources
- VPC and networking components
- ECR repository and images
- All associated AWS resources

## Troubleshooting

### Browser Creation Timeout
If browsers fail to create with timeout errors:
1. Check Ray worker resources: Workers need at least 1 CPU per browser actor
2. Verify node capacity: `kubectl get nodes`
3. Check Ray cluster status: `kubectl get rayservice -n ray-system`

### Connection Issues
If unable to connect to the endpoint:
1. Verify security groups allow inbound traffic on port 8050
2. Check Load Balancer status: `kubectl describe svc -n ray-system browser-cluster-public`
3. Ensure EKS cluster has internet access through NAT gateway