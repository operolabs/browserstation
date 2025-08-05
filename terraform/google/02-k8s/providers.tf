# 02-k8s/providers.tf

terraform {
  required_version = ">= 1.6"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.12"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.37"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17"
    }
    kubectl = {
      source  = "alekc/kubectl"
      version = "~> 2.1"
    }
  }
}

# Read outputs from infrastructure stage
data "terraform_remote_state" "infra" {
  backend = "local"
  config = {
    path = "../01-infra/terraform.tfstate"
  }
}

# Configure Google provider
provider "google" {
  project = data.terraform_remote_state.infra.outputs.project_id
  region  = data.terraform_remote_state.infra.outputs.region
}

# Get GKE cluster credentials
data "google_client_config" "default" {}

# Configure Kubernetes provider
provider "kubernetes" {
  host                   = "https://${data.terraform_remote_state.infra.outputs.cluster_endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(data.terraform_remote_state.infra.outputs.cluster_ca_data)
}

# Configure Helm provider
provider "helm" {
  kubernetes {
    host                   = "https://${data.terraform_remote_state.infra.outputs.cluster_endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(data.terraform_remote_state.infra.outputs.cluster_ca_data)
  }
}

# Configure kubectl provider
provider "kubectl" {
  host                   = "https://${data.terraform_remote_state.infra.outputs.cluster_endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(data.terraform_remote_state.infra.outputs.cluster_ca_data)
  load_config_file       = false
}