# 02-k8s/main.tf


# Ray namespace
resource "kubernetes_namespace" "ray_system" {
  metadata {
    name = "ray-system"
  }
}

# API key secret (only created if API key is provided)
resource "kubernetes_secret" "browserstation_api_key" {
  count = var.browserstation_api_key == "" ? 0 : 1

  metadata {
    name      = "browserstation-api-key"
    namespace = kubernetes_namespace.ray_system.metadata[0].name
  }

  data = {
    BROWSERSTATION_API_KEY = var.browserstation_api_key
  }
  
  type = "Opaque"
}

# KubeRay operator
resource "helm_release" "kuberay_operator" {
  name       = "kuberay-operator"
  repository = "https://ray-project.github.io/kuberay-helm/"
  chart      = "kuberay-operator"
  version    = "1.3.0"
  namespace  = kubernetes_namespace.ray_system.metadata[0].name

  set {
    name  = "operator.resources.requests.cpu"
    value = "100m"
  }
  set {
    name  = "operator.resources.requests.memory"
    value = "128Mi"
  }
}

# RayService for BrowserStation
resource "kubectl_manifest" "browserstation_rayservice" {
  yaml_body = templatefile("${path.module}/templates/rayservice.yaml.tpl", {
    namespace       = kubernetes_namespace.ray_system.metadata[0].name
    image          = "${data.terraform_remote_state.infra.outputs.ecr_repository_url}:latest"
    max_workers    = data.terraform_remote_state.infra.outputs.worker_max_size
    ray_version    = var.ray_version
    api_key_secret = var.browserstation_api_key != "" ? kubernetes_secret.browserstation_api_key[0].metadata[0].name : ""
  })
  
  depends_on = [
    helm_release.kuberay_operator,
    kubernetes_secret.browserstation_api_key
  ]
}

# Public LoadBalancer service
resource "kubernetes_service" "browser_cluster_public" {
  metadata {
    name      = "browser-cluster-public"
    namespace = kubernetes_namespace.ray_system.metadata[0].name
  }
  
  spec {
    type = "LoadBalancer"
    
    selector = {
      "app.kubernetes.io/name" = "kuberay"
      "ray.io/node-type"       = "head"
    }
    
    port {
      name        = "serve"
      port        = 8050
      target_port = 8050
    }
  }
  
  depends_on = [kubectl_manifest.browserstation_rayservice]
}