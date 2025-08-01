# 01-infra/main.tf

# Enable required APIs
resource "google_project_service" "required_apis" {
  for_each = toset([
    "compute.googleapis.com",
    "container.googleapis.com",
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com",
  ])

  project = var.project_id
  service = each.value

  disable_on_destroy = false
}

# VPC Network
resource "google_compute_network" "vpc" {
  name                    = "gke-${var.cluster_name}"
  auto_create_subnetworks = false
  project                 = var.project_id

  depends_on = [google_project_service.required_apis]
}

# Subnet
resource "google_compute_subnetwork" "subnet" {
  name          = "gke-${var.cluster_name}-subnet"
  network       = google_compute_network.vpc.self_link
  region        = var.region
  ip_cidr_range = var.network_cidr

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.1.0.0/16"
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.2.0.0/16"
  }
}

# Cloud Router (for NAT)
resource "google_compute_router" "router" {
  name    = "gke-${var.cluster_name}-router"
  region  = var.region
  network = google_compute_network.vpc.id
}

# Cloud NAT
resource "google_compute_router_nat" "nat" {
  name                               = "gke-${var.cluster_name}-nat"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

# GKE Cluster
resource "google_container_cluster" "primary" {
  provider = google-beta

  name     = var.cluster_name
  location = var.region

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = google_compute_network.vpc.self_link
  subnetwork = google_compute_subnetwork.subnet.self_link

  # Cluster version
  min_master_version = var.kubernetes_version

  # IP allocation policy for VPC-native cluster
  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  # Enable workload identity
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Private cluster config
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

  # Master authorized networks
  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = "0.0.0.0/0"
      display_name = "All"
    }
  }

  resource_labels = local.common_labels

  depends_on = [
    google_project_service.required_apis,
    google_compute_subnetwork.subnet,
  ]
}

# CPU Node Pool (for Ray head)
resource "google_container_node_pool" "cpu_nodes" {
  name       = "cpu-nodes"
  location   = var.region
  cluster    = google_container_cluster.primary.name
  node_count = 1

  node_config {
    machine_type = var.head_node_machine_type

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    labels = {
      "node-type" = "cpu"
    }

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    resource_labels = local.common_labels
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }
}

# Browser Worker Node Pool
resource "google_container_node_pool" "browser_workers" {
  name     = "browser-workers"
  location = var.region
  cluster  = google_container_cluster.primary.name

  autoscaling {
    min_node_count = var.worker_node_config.min_size
    max_node_count = var.worker_node_config.max_size
  }

  initial_node_count = var.worker_node_config.initial_size

  node_config {
    machine_type = var.worker_node_machine_type

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    labels = {
      "node-type" = "browser-worker"
    }

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    resource_labels = local.common_labels
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }
}

# Artifact Registry Repository
resource "google_artifact_registry_repository" "browser_api" {
  location      = var.region
  repository_id = "${var.cluster_name}-browser-api"
  description   = "Docker repository for browser API images"
  format        = "DOCKER"

  labels = local.common_labels

  depends_on = [google_project_service.required_apis]
}