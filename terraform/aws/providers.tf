# providers.tf

terraform {
  required_version = ">= 1.6"
  required_providers {
    aws        = { source = "hashicorp/aws",  version = "~> 5.95" }
    kubernetes = { source = "hashicorp/kubernetes", version = "~> 2.37" }
    helm       = { source = "hashicorp/helm", version = "~> 2.17" }
  }
}

provider "aws" {
  region = var.region
}

