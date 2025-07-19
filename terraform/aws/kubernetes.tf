###############################################################################
# kubernetes.tf – makes Kubernetes & Helm providers wait for the EKS cluster
###############################################################################

# Wait until the EKS control‑plane exists, **then** read its endpoint & cert
data "aws_eks_cluster" "this" {
  name       = module.eks.cluster_name
  depends_on = [module.eks]            # <- critical!
}

data "aws_eks_cluster_auth" "this" {
  name       = module.eks.cluster_name
  depends_on = [module.eks]
}

# Default Kubernetes provider – will use the values above
provider "kubernetes" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.this.token
}

# Default Helm provider, driven by the same connection
provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

# Ray namespace
resource "kubernetes_namespace" "ray_system" {
  metadata {
    name = "ray-system"
  }
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
resource "kubernetes_manifest" "browserstation_rayservice" {
  manifest = {
    apiVersion = "ray.io/v1"
    kind       = "RayService"
    metadata = {
      name      = "browser-cluster"
      namespace = kubernetes_namespace.ray_system.metadata[0].name
    }
    spec = {
      deploymentUnhealthySecondThreshold = 300
      serveConfigV2 = jsonencode({
        applications = []
      })
      rayClusterConfig = {
        headGroupSpec = {
          serviceType = "ClusterIP"
          rayStartParams = {
            "dashboard-host" = "0.0.0.0"
          }
          template = {
            spec = {
              containers = [{
                name            = "ray-head"
                image           = "${aws_ecr_repository.browser_api.repository_url}:latest"
                imagePullPolicy = "IfNotPresent"
                ports = [{
                  containerPort = 6379
                  name          = "redis"
                }, {
                  containerPort = 8265
                  name          = "dashboard"
                }, {
                  containerPort = 10001
                  name          = "client"
                }, {
                  containerPort = 8050
                  name          = "serve"
                }]
                command = ["/bin/bash", "-c", <<-EOT
                  ray start --head --port=6379 \
                  --dashboard-host=0.0.0.0 --metrics-export-port=8080 \
                  --num-cpus=0 --block & \
                  sleep 5 && uvicorn app.main:app --host 0.0.0.0 --port 8050
                EOT
                ]
              }]
            }
          }
        }
        workerGroupSpecs = [{
          groupName    = "browser-workers"
          minReplicas  = 0
          maxReplicas  = var.worker_node_config.max_size
          rayStartParams = {}
          template = {
            spec = {
              containers = [
                {
                  name            = "ray-worker"
                  image           = "${aws_ecr_repository.browser_api.repository_url}:latest"
                  imagePullPolicy = "IfNotPresent"
                  resources = {
                    requests = { cpu = "1", memory = "512Mi" }
                    limits   = { cpu = "2", memory = "1Gi" }
                  }
                },
                {
                  name  = "chrome"
                  image = "zenika/alpine-chrome:100"
                  args  = ["--no-sandbox", "--remote-debugging-address=0.0.0.0", "--remote-debugging-port=9222"]
                  ports = [{
                    containerPort = 9222
                    name          = "devtools"
                  }]
                  resources = {
                    requests = { cpu = "900m", memory = "768Mi" }
                    limits   = { cpu = "900m", memory = "1Gi" }
                  }
                }
              ]
            }
          }
        }]
      }
    }
  }
  depends_on = [
    helm_release.kuberay_operator,
    null_resource.docker_build_push
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
  depends_on = [kubernetes_manifest.browserstation_rayservice]
}