variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "eks-atlantis-cluster"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-north-1"
}

variable "github_username" {
  description = "GitHub username"
  type        = string
}

variable "github_token" {
  description = "GitHub personal access token"
  type        = string
  sensitive   = true
}

variable "github_repo" {
  description = "GitHub repository in format owner/repo"
  type        = string
}

variable "atlantis_version" {
  description = "Atlantis Helm chart version"
  type        = string
  default     = "4.21.0"
}

variable "atlantis_image_tag" {
  description = "Atlantis Docker image tag"
  type        = string
  default     = "v0.26.0"
}

variable "node_instance_type" {
  description = "EC2 instance type for EKS nodes"
  type        = string
  default     = "t3.medium"
}

variable "node_min_size" {
  description = "Minimum number of nodes"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum number of nodes"
  type        = number
  default     = 2
}

variable "node_desired_size" {
  description = "Desired number of nodes"
  type        = number
  default     = 1
}

variable "use_persistent_storage" {
  description = "Whether to use persistent storage for Atlantis (true for production, false for testing)"
  type        = bool
  default     = true
}

variable "storage_size" {
  description = "Storage size for Atlantis persistent volume"
  type        = string
  default     = "50Gi"
}
