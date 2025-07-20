output "browserstation_endpoint" {
  description = "The endpoint for BrowserStation API"
  value       = kubernetes_service.browser_cluster_public.status[0].load_balancer[0].ingress[0].hostname
}