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

output "browserstation_endpoint" {
  description = "BrowserStation service endpoint"
  value       = try(kubernetes_service.browser_cluster_public.status[0].load_balancer[0].ingress[0].hostname, "pending...")
}

output "next_steps" {
  description = "Next steps to use BrowserStation"
  value = <<-EOT
    ✅ Deployment complete!
    
    🌐 BrowserStation endpoint: ${try(kubernetes_service.browser_cluster_public.status[0].load_balancer[0].ingress[0].hostname, "pending...")}
    
    Test with:
    curl http://${try(kubernetes_service.browser_cluster_public.status[0].load_balancer[0].ingress[0].hostname, "ENDPOINT")}:8050/
  EOT
}

