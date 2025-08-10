# 01-infra/locals.tf

locals {
  common_labels = {
    project     = var.cluster_name
    environment = "production"
    managed_by  = "terraform"
  }
}