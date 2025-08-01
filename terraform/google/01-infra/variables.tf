# 01-infra/variables.tf

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region to deploy resources in"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "The GCP zone for zonal resources"
  type        = string
  default     = "us-central1-a"
}

variable "cluster_name" {
  description = "The name of the GKE cluster"
  type        = string
  default     = "browserstation"
}

variable "kubernetes_version" {
  description = "GKE control plane version (use 'latest' or specific version like '1.31')"
  type        = string
  default     = "1.31"
}

variable "head_node_machine_type" {
  description = "Machine type for Ray head node"
  type        = string
  default     = "n2-standard-2" # Equivalent to c5.large (2 vCPU, 8GB RAM)
}

variable "worker_node_machine_type" {
  description = "Machine type for browser worker nodes"
  type        = string
  default     = "n2-standard-16" # Equivalent to c5.4xlarge (16 vCPU, 64GB RAM)
}

variable "worker_node_config" {
  description = "Browser worker node scaling configuration"
  type = object({
    min_size     = number
    initial_size = number
    max_size     = number
  })
  default = {
    min_size     = 1
    initial_size = 2
    max_size     = 3
  }
}

variable "network_cidr" {
  description = "CIDR block for the VPC network"
  type        = string
  default     = "10.0.0.0/16"
}