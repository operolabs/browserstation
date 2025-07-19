# outputs.tf

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

output "region" {
  description = "AWS region"
  value       = var.region
}

output "kubeconfig_command" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"
}

output "ecr_repository_url" {
  description = "ECR repository URL for browser-api image"
  value       = aws_ecr_repository.browser_api.repository_url
}

output "next_steps" {
  description = "Next steps to deploy BrowserStation"
  value = <<-EOT
    ✅ Infrastructure created successfully!
    
    📄 A deployment script has been generated: ./deploy_to_eks.sh
    
    To deploy BrowserStation, simply run:
       ./deploy_to_eks.sh
    
    This script will:
    - Configure kubectl
    - Install KubeRay operator
    - Build and push Docker image
    - Deploy the Ray cluster
    - Show you the service endpoint
    
    For manual deployment steps, see the generated script.
  EOT
}