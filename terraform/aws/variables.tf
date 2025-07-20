
# variables.tf

variable "region" {
    description = "The AWS region to deploy resources in"
    type = string
    default = "us-east-1"
}

variable "cluster_name" {
    description = "The name of the EKS cluster"
    type = string
    default = "browserstation"
}

variable "kubernetes_version" {
    description = "EKS control plane version"
    type = string
    default = "1.31"
}

variable "head_node_instance_type" {
    description = "Instance type for Ray head node"
    type = string
    default = "c5.large"
}

variable "worker_node_instance_type" {
    description = "Instance type for browser worker nodes"
    type = string
    default = "c5.4xlarge"
}

variable "worker_node_config" {
    description = "Browser worker node scaling configuration"
    type = object({
        min_size     = number
        desired_size = number
        max_size     = number
    })
    default = {
        min_size     = 1
        desired_size = 2
        max_size     = 3
    }
}

variable "ray_version" {
  description = "Ray version to deploy – must match the image baked into ECR"
  type        = string
  default     = "2.47.1" 
}

variable "browserstation_api_key" {
  description = "API key for BrowserStation authentication. If empty, authentication is disabled."
  type        = string
  default     = ""
  sensitive   = true
}
