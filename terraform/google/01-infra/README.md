# Google Cloud Infrastructure for BrowserStation

This directory contains Terraform configuration for deploying BrowserStation infrastructure on Google Cloud Platform.

## Prerequisites

1. **Google Cloud CLI** (`gcloud`) installed and configured
2. **Terraform** >= 1.6
3. **Docker** with buildx support
4. A Google Cloud project with billing enabled

## Components

This Terraform configuration creates:

- **VPC Network**: Custom VPC with subnet for GKE
- **GKE Cluster**: Regional Google Kubernetes Engine cluster
- **Node Pools**:
  - CPU nodes: For Ray head node (n2-standard-2)
  - Browser workers: Auto-scaling pool for browser workloads (n2-standard-16)
- **Artifact Registry**: Docker repository for container images
- **Cloud NAT**: For outbound internet access from private nodes

## Usage

1. **Initialize Terraform**:
   ```bash
   terraform init
   ```

2. **Set required variables**:
   Create a `terraform.tfvars` file:
   ```hcl
   project_id = "your-gcp-project-id"
   region     = "us-central1"  # or your preferred region
   ```

3. **Review the plan**:
   ```bash
   terraform plan
   ```

4. **Apply the configuration**:
   ```bash
   terraform apply
   ```

5. **Configure kubectl**:
   ```bash
   gcloud container clusters get-credentials browserstation --region <your-region>
   ```

## Machine Type Mapping

| AWS Instance | GCP Machine Type | vCPUs | Memory |
|--------------|------------------|-------|--------|
| c5.large     | n2-standard-2    | 2     | 8 GB   |
| c5.4xlarge   | n2-standard-16   | 16    | 64 GB  |

## Customization

You can customize the deployment by overriding variables:

```hcl
# terraform.tfvars
project_id               = "my-project"
region                  = "europe-west1"
cluster_name            = "my-browserstation"
kubernetes_version      = "1.31"
head_node_machine_type  = "n2-standard-4"
worker_node_machine_type = "n2-highmem-8"
worker_node_config = {
  min_size     = 2
  initial_size = 3
  max_size     = 10
}
```

## Deletion Protection

By default, the GKE cluster is created with deletion protection enabled to prevent accidental deletion. To destroy the cluster, you must first disable deletion protection:

```hcl
# terraform.tfvars
deletion_protection = false
```

Then apply the change:
```bash
terraform apply -target=google_container_cluster.primary
```

After this, you can run `terraform destroy` or use the teardown script.

## Authentication

The Docker build process uses `gcloud auth configure-docker` to authenticate with Artifact Registry. Ensure you're authenticated with Google Cloud:

```bash
gcloud auth login
gcloud config set project <your-project-id>
```

## Outputs

After successful deployment, Terraform will output:

- `cluster_name`: Name of the GKE cluster
- `cluster_endpoint`: GKE control plane endpoint
- `cluster_ca_data`: Cluster CA certificate
- `artifact_registry_url`: URL for pushing Docker images
- `project_id`: GCP project ID
- `region`: Deployment region
- `worker_max_size`: Maximum worker node count
- `network_name`: VPC network name
- `subnet_name`: Subnet name

## Clean Up

To destroy all resources:

```bash
terraform destroy
```

## Notes

- The cluster is configured as a private GKE cluster with public endpoint access
- Workload Identity is enabled for secure pod authentication
- Node auto-repair and auto-upgrade are enabled for maintenance
- The infrastructure includes Cloud NAT for outbound internet access from private nodes