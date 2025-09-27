# Google Cloud Kubernetes Deployment

This directory contains Terraform configuration for deploying BrowserStation on Google Kubernetes Engine (GKE).

## Prerequisites

1. Complete the infrastructure deployment in `../01-infra`
2. Ensure you have the following tools installed:
   - Terraform >= 1.6
   - Google Cloud SDK (`gcloud`)
   - `kubectl`
   - `helm`

## Configuration

The deployment reads outputs from the infrastructure stage (01-infra) including:
- GKE cluster endpoint and credentials
- Google Artifact Registry URL
- Worker node configuration

## Variables

- `browserstation_api_key`: (Optional) API key for BrowserStation authentication
- `ray_version`: Ray version to deploy (default: 2.47.1)

## Deployment Steps

1. Authenticate with Google Cloud:
   ```bash
   gcloud auth application-default login
   ```

2. Initialize Terraform:
   ```bash
   terraform init
   ```

3. Review the deployment plan:
   ```bash
   terraform plan
   ```

4. Apply the configuration:
   ```bash
   terraform apply
   ```

5. Get the BrowserStation endpoint:
   ```bash
   terraform output browserstation_endpoint
   ```

## Components Deployed

1. **Ray System Namespace**: Kubernetes namespace for Ray components
2. **BrowserStation API Key Secret**: (Optional) Kubernetes secret for API authentication
3. **KubeRay Operator**: Manages Ray clusters on Kubernetes
4. **RayService**: Deploys BrowserStation with auto-scaling workers
5. **LoadBalancer Service**: Exposes BrowserStation API publicly

## Accessing BrowserStation

After deployment, the BrowserStation API will be available at:
```
http://<LOAD_BALANCER_IP>:8050
```

You can get the IP address with:
```bash
terraform output browserstation_endpoint
```

## Cleanup

To remove all resources:
```bash
terraform destroy
```