# Data sources
data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

data "aws_caller_identity" "current" {}

# VPC Module
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.cluster_name}-vpc-${random_string.suffix.result}"
  cidr = "10.0.0.0/16"

  azs             = slice(data.aws_availability_zones.available.names, 0, 2)
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }

  tags = merge(local.common_tags, {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  })
}

# EKS Module - WITHOUT EBS CSI addon initially
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.28"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  cluster_enabled_log_types = ["api", "audit"]

  eks_managed_node_groups = {
    main = {
      name           = "main-nodes-${random_string.suffix.result}"
      instance_types = [var.node_instance_type]
      
      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size

      vpc_security_group_ids = [aws_security_group.node_group.id]
      
      enable_monitoring      = true
      create_launch_template = true
      launch_template_name   = "main-lt-${random_string.suffix.result}"
      
      disk_size = 50
      disk_type = "gp3"
      
      labels = {
        "workload"     = "general"
        "environment"  = "testing"
      }
      
      block_device_mappings = [
        {
          device_name = "/dev/xvda"
          ebs = {
            volume_size = 50
            volume_type = "gp3"
            iops        = 3000
            throughput  = 125
            encrypted   = true
          }
        }
      ]
    }
  }

  manage_aws_auth_configmap = true
  aws_auth_roles = [
    {
      rolearn  = aws_iam_role.eks_admin.arn
      username = "eks-admin"
      groups   = ["system:masters"]
    },
    {
      rolearn  = aws_iam_role.eks_read_only.arn
      username = "eks-read-only"
      groups   = ["system:authenticated"]
    },
  ]

  # Only install core addons initially - NO EBS CSI driver here
  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
  }

  tags = local.common_tags
}

# EBS CSI Driver IRSA Role - Created AFTER EKS cluster
module "ebs_csi_irsa_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name = "${var.cluster_name}-ebs-csi-driver-${random_string.suffix.result}"
  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

  depends_on = [module.eks]
}

# EBS CSI Driver Addon - Added separately to break the cycle
resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name             = module.eks.cluster_name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = data.aws_eks_addon_version.ebs_csi.version
  service_account_role_arn = module.ebs_csi_irsa_role.iam_role_arn
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [
    module.eks,
    module.ebs_csi_irsa_role
  ]
}

# Get the latest EBS CSI driver version
data "aws_eks_addon_version" "ebs_csi" {
  addon_name         = "aws-ebs-csi-driver"
  kubernetes_version = module.eks.cluster_version
  most_recent        = true
}

# Security Group
resource "aws_security_group" "node_group" {
  name_prefix = "${var.cluster_name}-node-group-${random_string.suffix.result}"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "Atlantis webhook HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Atlantis webhook HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Atlantis internal"
    from_port   = 4141
    to_port     = 4141
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  ingress {
    description = "Node to node"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    self        = true
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-node-group-sg"
  })
}

# IAM Roles
resource "aws_iam_role" "eks_admin" {
  name = "${var.cluster_name}-eks-admin-${random_string.suffix.result}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
      },
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role" "eks_read_only" {
  name = "${var.cluster_name}-eks-read-only-${random_string.suffix.result}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
      },
    ]
  })

  tags = local.common_tags
}

# Kubernetes RBAC
resource "kubernetes_cluster_role" "eks_read_only" {
  metadata {
    name = "eks-read-only"
  }

  rule {
    api_groups = [""]
    resources  = ["*"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["apps", "extensions"]
    resources  = ["*"]
    verbs      = ["get", "list", "watch"]
  }

  depends_on = [module.eks]
}

resource "kubernetes_cluster_role_binding" "eks_read_only" {
  metadata {
    name = "eks-read-only"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.eks_read_only.metadata[0].name
  }

  subject {
    kind      = "User"
    name      = "eks-read-only"
    api_group = "rbac.authorization.k8s.io"
  }

  depends_on = [module.eks]
}

# Storage Class
resource "kubernetes_storage_class" "atlantis_production" {
  metadata {
    name = "atlantis-production"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "false"
    }
  }

  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy        = "Retain"
  volume_binding_mode   = "WaitForFirstConsumer"
  allow_volume_expansion = true
  parameters = {
    type      = "gp3"
    encrypted = "true"
    fsType    = "ext4"
  }

  depends_on = [aws_eks_addon.ebs_csi_driver]
}

# Atlantis Namespace
resource "kubernetes_namespace" "atlantis" {
  metadata {
    name = "atlantis"
    labels = {
      "name" = "atlantis"
    }
  }

  depends_on = [module.eks]
}

# Atlantis IRSA
resource "aws_iam_role" "atlantis_role" {
  name = "${var.cluster_name}-atlantis-role-${random_string.suffix.result}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Federated = module.eks.oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:atlantis:atlantis"
            "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "atlantis_policy" {
  name = "${var.cluster_name}-atlantis-policy-${random_string.suffix.result}"
  role = aws_iam_role.atlantis_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:*",
          "eks:*",
          "iam:*",
          "s3:*",
          "cloudformation:*",
          "autoscaling:*",
          "elasticloadbalancing:*"
        ]
        Resource = "*"
      }
    ]
  })
}

# Atlantis Helm Release
resource "helm_release" "atlantis" {
  name       = "atlantis"
  repository = "https://runatlantis.github.io/helm-charts"
  chart      = "atlantis"
  version    = var.atlantis_version
  namespace  = kubernetes_namespace.atlantis.metadata[0].name
  timeout    = 1800

  values = [
    templatefile("${path.module}/values.yaml.tpl", {
      github_repo_allowlist = local.github_repo_allowlist
      github_username      = var.github_username
      github_token         = var.github_token
      webhook_secret       = local.webhook_secret
      atlantis_image_tag   = var.atlantis_image_tag
      requests_memory      = local.atlantis_resources.requests.memory
      requests_cpu         = local.atlantis_resources.requests.cpu
      limits_memory        = local.atlantis_resources.limits.memory
      limits_cpu           = local.atlantis_resources.limits.cpu
      atlantis_role_arn    = aws_iam_role.atlantis_role.arn
      region               = var.region
      storage_size         = var.storage_size
    })
  ]

  depends_on = [
    kubernetes_namespace.atlantis,
    aws_iam_role_policy.atlantis_policy,
    kubernetes_storage_class.atlantis_production,
    module.ebs_csi_irsa_role,
    aws_eks_addon.ebs_csi_driver,
    module.eks
  ]
}

# Get LoadBalancer URL
data "kubernetes_service" "atlantis" {
  metadata {
    name      = "atlantis"
    namespace = "atlantis"
  }
  
  depends_on = [helm_release.atlantis]
}

# Atlantis Verification
resource "null_resource" "atlantis_verification" {
  triggers = {
    cluster_name = module.eks.cluster_name
    service_url  = try(data.kubernetes_service.atlantis.status.0.load_balancer.0.ingress.0.hostname, "pending")
  }

  depends_on = [helm_release.atlantis]
}
