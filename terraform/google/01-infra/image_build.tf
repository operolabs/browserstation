# 01-infra/image_build.tf

# Docker build and push to Artifact Registry
resource "null_resource" "docker_build_push" {
  triggers = {
    dockerfile_sha = filesha256("${path.module}/../../../Dockerfile.x86_64")
    app_sha        = filesha256("${path.module}/../../../app/main.py")
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<EOC
set -euo pipefail

echo "🔐  Configuring Docker for Artifact Registry..."
gcloud auth configure-docker ${var.region}-docker.pkg.dev --quiet

echo "🏗   Building image..."
docker buildx build --platform linux/amd64 \
  -t ${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.browser_api.repository_id}/browser-api:latest \
  -f ../../../Dockerfile.x86_64 ../../../

echo "📤  Pushing image..."
docker push ${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.browser_api.repository_id}/browser-api:latest
EOC
  }

  depends_on = [google_artifact_registry_repository.browser_api]
}