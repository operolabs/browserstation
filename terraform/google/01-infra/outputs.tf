# 01-infra/outputs.tf

output "cluster_name" {
  description = "Name of the GKE cluster"
  value       = google_container_cluster.primary.name
}

output "cluster_endpoint" {
  description = "Endpoint for GKE control plane"
  value       = google_container_cluster.primary.endpoint
}

output "cluster_ca_data" {
  description = "Base64 encoded certificate data for GKE cluster"
  value       = google_container_cluster.primary.master_auth[0].cluster_ca_certificate
}

output "artifact_registry_url" {
  description = "URL of the Artifact Registry repository"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.browser_api.repository_id}"
}

output "project_id" {
  description = "GCP project ID"
  value       = var.project_id
}

output "region" {
  description = "GCP region"
  value       = var.region
}

output "worker_max_size" {
  description = "Maximum number of worker nodes"
  value       = var.worker_node_config.max_size
}

output "network_name" {
  description = "Name of the VPC network"
  value       = google_compute_network.vpc.name
}

output "subnet_name" {
  description = "Name of the subnet"
  value       = google_compute_subnetwork.subnet.name
}