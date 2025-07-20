# kuberenetes.tf

# Configure Kubernetes provider using exec authentication
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

# Configure Helm provider using exec authentication
provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}

# Configure kubectl provider using exec authentication
provider "kubectl" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  load_config_file       = false
  
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

# Ray namespace
resource "kubernetes_namespace" "ray_system" {
  metadata {
    name = "ray-system"
  }
  
  depends_on = [module.eks]
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
  
  depends_on = [module.eks]
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
  
  depends_on = [module.eks]
}

# RayService for BrowserStation using kubectl provider
resource "kubectl_manifest" "browserstation_rayservice" {
  yaml_body = templatefile("${path.module}/templates/rayservice.yaml.tpl", {
    namespace        = kubernetes_namespace.ray_system.metadata[0].name
    image           = "${aws_ecr_repository.browser_api.repository_url}:latest"
    max_workers     = var.worker_node_config.max_size
    api_key_secret  = var.browserstation_api_key != "" ? kubernetes_secret.browserstation_api_key[0].metadata[0].name : ""
  })
  
  depends_on = [
    helm_release.kuberay_operator,
    null_resource.docker_build_push,
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