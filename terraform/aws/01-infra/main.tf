# 01-infra/main.tf


# VPC
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.16.0"

  name = "eks-${var.cluster_name}"
  cidr = "10.0.0.0/16"
  azs  = ["${var.region}a", "${var.region}b"]

  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true

  tags = local.common_tags
}

# EKS Cluster
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.37.2"

  cluster_name                             = var.cluster_name
  cluster_version                          = var.kubernetes_version
  cluster_endpoint_public_access           = true
  cluster_endpoint_private_access          = true
  enable_cluster_creator_admin_permissions = true
  bootstrap_self_managed_addons            = true

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

  cluster_addons = {
    vpc-cni = {
      addon_version               = "v1.19.2-eksbuild.1"
      resolve_conflicts_on_update = "OVERWRITE"
    }
    kube-proxy = {
      addon_version               = "v1.32.0-eksbuild.2"
      resolve_conflicts_on_update = "OVERWRITE"
    }
    aws-ebs-csi-driver = {
      addon_version               = "v1.45.0-eksbuild.2"
      resolve_conflicts_on_update = "OVERWRITE"
    }
  }

  tags = local.common_tags
}

# ECR Repository
resource "aws_ecr_repository" "browser_api" {
  name                 = "${var.cluster_name}-browser-api"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
  image_scanning_configuration {
    scan_on_push = true
  }
  tags = local.common_tags
}