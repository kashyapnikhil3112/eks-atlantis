output "eks_oidc_provider_url" {
  description = "EKS OIDC provider URL for IRSA integration"
  value       = module.eks.cluster_oidc_issuer_url
}

output "eks_node_group_role_arn" {
  description = "EKS managed node group IAM role ARN"
  value       = module.eks.eks_managed_node_groups["main"].iam_role_arn
}

output "vpc_id" {
  description = "VPC ID for the EKS cluster"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs used by EKS nodes"
  value       = module.vpc.private_subnets
}

output "public_subnet_ids" {
  description = "Public subnet IDs in the VPC"
  value       = module.vpc.public_subnets
}

output "atlantis_pod_names" {
  description = "Atlantis pod names for troubleshooting/log access"
  value = try(
    [for p in data.kubernetes_service.atlantis.metadata[*].name : p],
    []
  )
}
output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "kubectl_config_command" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"
}

output "atlantis_url" {
  description = "Atlantis LoadBalancer URL"
  value       = try(
    "http://${data.kubernetes_service.atlantis.status.0.load_balancer.0.ingress.0.hostname}",
    "LoadBalancer not ready yet - wait 3-5 minutes"
  )
}

output "atlantis_webhook_url" {
  description = "GitHub webhook URL"
  value       = try(
    "http://${data.kubernetes_service.atlantis.status.0.load_balancer.0.ingress.0.hostname}/events",
    "LoadBalancer not ready yet - wait 3-5 minutes"
  )
}

output "atlantis_webhook_secret" {
  description = "Auto-generated webhook secret"
  value       = local.webhook_secret
  sensitive   = true
}

output "github_setup_instructions" {
  description = "GitHub webhook setup instructions"
  sensitive   = true  # Add this line
  value = <<-EOT
    ################ GitHub Webhook Setup#######:
    1. Go to: https://github.com/${var.github_repo}/settings/hooks
    2. Click "Add webhook"
    3. Payload URL: ${try("http://${data.kubernetes_service.atlantis.status.0.load_balancer.0.ingress.0.hostname}/events", "LoadBalancer not ready yet")}
    4. Content type: application/json
    5. Secret: ${local.webhook_secret}
    6. Events: Pull requests, Issue comments, Pull request reviews, Push
    7. Active: ✓
  EOT
}


output "atlantis_service_account_role_arn" {
  description = "Atlantis service account IAM role ARN"
  value       = aws_iam_role.atlantis_role.arn
}

output "verification_commands" {
  description = "Commands to verify deployment"
  value = <<-EOT
    ################# Verification Commands############:
    
    1. Update kubectl: aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}
    2. Check pods: kubectl get pods -n atlantis
    3. Check service: kubectl get svc -n atlantis
    4. Check logs: kubectl logs -n atlantis -l app.kubernetes.io/name=atlantis
    5. Test health: curl -I ${try("http://${data.kubernetes_service.atlantis.status.0.load_balancer.0.ingress.0.hostname}/healthz", "LoadBalancer not ready yet")}
  EOT
}
