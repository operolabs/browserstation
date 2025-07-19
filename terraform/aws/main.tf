# main.tf

###############################################################################
# 1. Networking and EKS
###############################################################################
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.16.0"

  name = "eks-${var.cluster_name}"
  cidr = "10.0.0.0/16"
  azs  = ["us-east-1b", "us-east-1c"]

  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway  = true
  single_nat_gateway  = true

  tags = local.common_tags
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.37.2"

  cluster_name                    = var.cluster_name
  cluster_version                 = var.kubernetes_version
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true
  
  # Enable admin access for the cluster creator
  enable_cluster_creator_admin_permissions = true

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    cpu_nodes = {
      instance_types = [var.head_node_instance_type]
      min_size       = 1
      max_size       = 1
      desired_size   = 1
      labels         = { "node-type" = "cpu" }
    }

    browser_workers = {
      instance_types = [var.worker_node_instance_type]
      min_size       = var.worker_node_config.min_size
      max_size       = var.worker_node_config.max_size
      desired_size   = var.worker_node_config.desired_size
      labels         = { "node-type" = "browser-worker" }
    }
  }

  tags = local.common_tags
}

###############################################################################
# 2. ECR
###############################################################################
resource "aws_ecr_repository" "browser_api" {
  name                 = "${var.cluster_name}-browser-api"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
  image_scanning_configuration { scan_on_push = true }
  tags = local.common_tags
}

