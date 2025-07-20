locals {
  common_tags = {
    Project                                     = var.cluster_name
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}