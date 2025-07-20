# 01-infra/image_build.tf

# Docker build and push
resource "null_resource" "docker_build_push" {
  triggers = {
    dockerfile_sha = filesha256("${path.module}/../../../Dockerfile.x86_64")
    app_sha        = filesha256("${path.module}/../../../app/main.py")
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<EOC
set -euo pipefail

echo "🔐  Logging in to ECR..."
aws ecr get-login-password --region ${var.region} \
  | docker login --username AWS --password-stdin ${aws_ecr_repository.browser_api.repository_url}

echo "🏗   Building image..."
docker buildx build --platform linux/amd64 \
  -t ${aws_ecr_repository.browser_api.repository_url}:latest \
  -f ../../../Dockerfile.x86_64 ../../../

echo "📤  Pushing image..."
docker push ${aws_ecr_repository.browser_api.repository_url}:latest
EOC
  }
  
  depends_on = [aws_ecr_repository.browser_api]
}