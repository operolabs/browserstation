<h1 align="center">Production Deployment on AWS</h1>

**Browserstation** uses Terraform for maintainable infrastructure-as-code (IaC), enabling reproducible, developer-friendly production deployments.

> ⚠️ **Warning:** This is a minimal production environment. Review the [Security](#security) section for steps to properly secure your deployment.

## Deploy on Elastic Kubernetes Service (EKS)

### Step 1: Preparation

- Install [kubectl](https://kubernetes.io/docs/tasks/tools/) (>= 1.23), [Helm](https://helm.sh/docs/intro/install/) (>= 3.4), [Kind](https://kind.sigs.k8s.io/), and [Docker](https://docs.docker.com/get-docker/).
- **NEW:** Install [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) (configure it with your IAM credentials) and [Terraform (>= 1.2)](https://developer.hashicorp.com/terraform/install).
- Make sure your AWS credentials are configured correctly with `AdministratorAccess` for simplicity. [Review IAM permissions here](#iam-permissions).

### Step 2: Create AWS Infrastructure (15–20 minutes)

Provision the EKS cluster and networking with Terraform.  
NAT gateway creation and EKS provisioning may take some time.

```bash
cd terraform/aws
terraform init
terraform apply -var="browserstation_api_key=your-secret-key" -auto-approve
````

### Step 3: Test Browserstation

After deployment completes (typically 10-15 minutes), Terraform will output:
```
browserstation_endpoint = "your-load-balancer-dns.elb.amazonaws.com"
```

Access your service with the API key at:
  `your-load-balancer-dns.elb.amazonaws.com:8050`


## Clean Up (\~10 minutes)

```bash
terraform destroy -auto-approve
```

## Security

By default, `cluster_endpoint_public_access = true` is set in `main.tf`, exposing the EKS control plane and LoadBalancer to the public internet.
**This is not secure for production.** The API key is only a basic layer of protection.

**For production:**

* Set `cluster_endpoint_public_access = false`
* Implement private networking and firewall rules
* Consider more advanced security controls for your cluster

## Configure

The default configuration is optimized for default service quotas.
To customize your setup, edit `variables.tf` to define the size of your backend based on your workload.

## IAM Permissions

The following IAM policies (Simple) are required for deployment:

* `AmazonEKSClusterPolicy`
* `AmazonEKSWorkerNodePolicy`
* `AmazonEKS_CNI_Policy`
* `AmazonEKSVPCResourceController`
* `AmazonEC2FullAccess`
* `ElasticLoadBalancingFullAccess`
* `AutoScalingFullAccess`
* `AmazonVPCFullAccess`
* `AmazonEC2ContainerRegistryFullAccess`
* `CloudWatchLogsFullAccess`
* `IAMFullAccess`

<br>
<div align="center">
  <sub>
    Made with ❤️ by <a href="https://www.operolabs.com/">OperoLabs</a>
  </sub>
</div>
