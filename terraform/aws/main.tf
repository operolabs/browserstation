
data "aws_caller_identity" "this" {}


module "vpc" {
    source = "terraform-aws-modules/vpc/aws"
    version = "5.16.0"

    name = "eks-${var.cluster_name}"
    cidr = "10.0.0.0/16"
    azs = ["us-east-1b", "us-east-1c"]
    private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
    public_subnets = ["10.0.101.0/24", "10.0.102.0/24"]
    enable_nat_gateway = true
    single_nat_gateway = true
    tags = {
        "kubernetes.io/cluster/${var.cluster_name}" = "shared"
        "Project" = var.cluster_name
    }
}

module "eks" {
    source = "terraform-aws-modules/eks/aws"
    version = "20.37.1"

    cluster_name = var.cluster_name
    cluster_version = var.kubernetes_version
    cluster_endpoint_private_access = true
    cluster_endpoint_public_access  = true

    # Cloud Watch
    cluster_enabled_log_types = ["api", "audit", "authenticator"]

    vpc_id = module.vpc.vpc_id
    subnet_ids = module.vpc.private_subnets
    control_plane_subnet_ids   = module.vpc.private_subnets 

    eks_managed_node_groups = {
        # CPU node group for Ray head and system pods
        cpu_nodes = {
            name = "cpu-node-group"
            ami_type = "AL2023_x86_64_STANDARD"  # Required for Kubernetes 1.31+
            instance_types = [var.head_node_instance_type]
            desired_size = 1
            min_size = 0
            max_size = 1
            disk_size = 100  # Reduced for cost savings
            
            labels = {
                "node-type" = "cpu"
            }
        }
        
        browser_workers = {
            name = "browser-workers"
            ami_type = "AL2023_x86_64_STANDARD"  # Required for Kubernetes 1.31+
            instance_types = [var.worker_node_instance_type]
            desired_size = var.worker_node_config.desired_size
            min_size = var.worker_node_config.min_size
            max_size = var.worker_node_config.max_size
            disk_size = 100  # Reduced for cost savings
            
            labels = {
                "node-type" = "browser-worker"
            }
        }
    }

    authentication_mode = "API"
    enable_cluster_creator_admin_permissions = true

    tags = { "Project" = var.cluster_name }
}

# ECR Repository for browser-api image
resource "aws_ecr_repository" "browser_api" {
    name = "${var.cluster_name}-browser-api"
    image_tag_mutability = "MUTABLE"
    force_delete = true
    
    image_scanning_configuration {
        scan_on_push = true
    }
    
    tags = { "Project" = var.cluster_name }
}
