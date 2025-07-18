locals {
  webhook_secret = random_password.webhook_secret.result
  github_repo_allowlist = "github.com/${var.github_username}/*"
  
  # Enhanced resource configuration
  atlantis_resources = {
    requests = {
      memory = var.use_persistent_storage ? "2Gi" : "1Gi"
      cpu = var.use_persistent_storage ? "1000m" : "500m"
    }
    limits = {
      memory = var.use_persistent_storage ? "8Gi" : "4Gi"
      cpu = var.use_persistent_storage ? "4000m" : "2000m"
    }
  }
  
  common_tags = {
    Environment = var.use_persistent_storage ? "production" : "testing"
    Project = "eks-atlantis"
    ManagedBy = "terraform"
    Owner = var.github_username
  }
}

resource "random_password" "webhook_secret" {
  length = 32
  special = true
  upper = true
  lower = true
  numeric = true
}

resource "random_string" "suffix" {
  length = 8
  special = false
  upper = false
}
