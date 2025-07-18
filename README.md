# EKS + Atlantis Deployment with Terraform & Helm

This project provides a production-ready, automated deployment of an Amazon EKS (Elastic Kubernetes Service) 
cluster with [Atlantis](https://www.runatlantis.io/) for GitOps-style Terraform automation, using Terraform and 
Helm. It is designed for real-world use in organizations that want to manage infrastructure as code (IaC) with 
strong security, scalability, and automation.

I have used Windows Powershell for the setup.

---

## Table of Contents
- [Architecture Overview](#architecture-overview)
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Setup & Deployment](#setup--deployment)
- [Production Considerations](#production-considerations)
- [Security Best Practices](#security-best-practices)
- [GitHub & Atlantis Integration](#github--atlantis-integration)
- [Usage Workflow](#usage-workflow)
- [Troubleshooting & Maintenance](#troubleshooting--maintenance)
- [References](#references)

---

## Architecture Overview

```
┌────────────┐      ┌──────────────┐      ┌──────────────┐
│  Developer │────▶│  GitHub Repo │────▶│  Atlantis    │
└────────────┘      └──────────────┘      │  (on EKS)   │
         ▲                ▲              └─────┬────────┘
         │                │                    │
         │                │                    ▼
         │         Webhooks/PRs         EKS Cluster
         │                │                    │
         │                │                    ▼
         │                │              AWS Resources
         │                │
         └────────────────┘
```

**Components:**
- VPC with public/private subnets
- EKS cluster (with managed node group)
- Atlantis (deployed via Helm)
- IAM roles for RBAC and IRSA
- EBS CSI driver for persistent storage
- Secure GitHub integration

---

## Features
- Automated, repeatable EKS + Atlantis deployment
- Secure RBAC and IAM role separation
- Persistent storage with EBS
- GitHub PR-driven Terraform automation
- Customizable for dev, staging, or production
- Outputs for easy `kubectl` and Atlantis access

---

## Prerequisites
- AWS account with sufficient permissions. Create a dedicated IAM user , for testing assign Admin Access previliges
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)

Initialize configuration****
aws configure

Or set individual values
aws configure set aws_access_key_id YOUR_ACCESS_KEY
aws configure set aws_secret_access_key YOUR_SECRET_KEY
aws configure set default.region us-west-2
aws configure set default.output json

Display all configuration
aws configure list

Check persistent environment variables stored at user level
echo "GitHub Token: $([Environment]::GetEnvironmentVariable('GITHUB_TOKEN', 'User').Substring(0,10))..."
echo "GitHub Username: $([Environment]::GetEnvironmentVariable('GITHUB_USERNAME', 'User'))"
echo "GitHub Repo: $([Environment]::GetEnvironmentVariable('GITHUB_REPO', 'User'))"
echo "AWS Region: $([Environment]::GetEnvironmentVariable('AWS_REGION', 'User'))"

Get all GitHub and AWS related environment variables
Get-ChildItem Env: | Where-Object { $_.Name -like "*GITHUB*" -or $_.Name -like "*AWS*" } | Format-Table Name, Value -AutoSize


- [Terraform](https://developer.hashicorp.com/terraform/downloads) >= 1.0

- [kubectl](https://kubernetes.io/docs/tasks/tools/)

- [Helm](https://helm.sh/docs/intro/install/)

- GitHub Personal Access Token (for Atlantis)

---

## Setup & Deployment

1. **Clone the repository**
   ```sh
   git clone <this-repo-url>
   cd <repo>/terraform
   ```
2. **Configure variables**
   - Copy `terraform.tfvars.example` to `terraform.tfvars` (or edit directly)
   - Fill in your AWS region, GitHub username, token, and repo
   
*****Example for terraform.tfvars that can be used is as below

*** Basic Configuration
cluster_name = "eks-atlantis-cluster"
region = "eu-north-1"

**** GitHub Configuration
github_username = "abc"
github_token = "ghp_abcd"
github_repo = "abc/eks-atlantis"

***** Atlantis Configuration
atlantis_version = "4.21.0"
atlantis_image_tag = "v0.26.0"

***** Node Configuration
node_instance_type = "t3.medium"
node_min_size = 1
node_max_size = 2
node_desired_size = 1

***** Storage Configuration
***** Set to false for testing (EmptyDir), true for production (Persistent Volume)
use_persistent_storage = true
storage_size = "50Gi"

Also you can setup your github and AWS details in your ENV variables to be persistent (Check how to do on powershell.)

3. **Initialize Terraform**
   ```sh
   terraform init
   ```
4. **Validate configuration**
   ```sh
   terraform validate
   ```
5. **Review the plan**
   ```sh
   terraform plan
   ```
6. **Apply the deployment**
   ```sh
   terraform apply -auto-approve
   ```
7. **Configure kubectl**
   ```sh
   aws eks update-kubeconfig --region <region> --name <cluster_name>
   ```
8. **Access Atlantis**
   - Get the Atlantis URL from Terraform outputs
   - Set up the GitHub webhook as described below

---

## Production Considerations
- **Remote State:** Use S3 + DynamoDB for Terraform state locking in production.
- **Secrets Management:** Never commit secrets to version control. Use environment variables or a secrets manager.
- **Scaling:** Adjust node group size and instance types for your workload.
- **Monitoring:** Integrate with AWS CloudWatch and enable EKS logging.
- **Backups:** Regularly backup EBS volumes and state files.

---

## Security Best Practices
- Restrict security group ingress to trusted IPs (not `0.0.0.0/0` in production).
- Use least-privilege IAM policies for Atlantis and EKS nodes.
- Enable encryption for EBS volumes and Kubernetes secrets.
- Rotate GitHub tokens and AWS credentials regularly.
- Enable audit logging on EKS.

---

## GitHub & Atlantis Integration
1. **Create a GitHub Personal Access Token** with `repo` and `admin:repo_hook` scopes.
2. **Configure Atlantis** with your GitHub username, token, and repo in `terraform.tfvars`.
3. **Set up the GitHub webhook:**
   - Go to your repo settings → Webhooks → Add webhook
   - Use the Atlantis URL from Terraform output (e.g., `http://<atlantis-lb>/events`)
   - Set the secret from the created secret 
kubectl get secrets -n atlantis
# View secret content
kubectl get secret atlantis-webhook -n atlantis -o jsonpath='{.data.github_secret}' | %{[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_))}
   - Select events: Pull requests, Issue comments, Pull request reviews, Push

---

## Usage Workflow
1. **Open a Pull Request** with Terraform changes
2. **Atlantis runs `plan`** and comments on the PR
3. **Review and approve** the plan in the PR
4. **Comment `atlantis apply`** to apply changes
5. **Monitor Atlantis and EKS** using `kubectl` and AWS Console

---

## Troubleshooting & Maintenance
- **Pods not starting?**
  - Check node group status and IAM permissions
  - Use `kubectl get pods -n atlantis` and `kubectl describe pod ...`
- **Atlantis not reachable?**
  - Check the LoadBalancer status: `kubectl get svc -n atlantis`
  - Ensure security groups allow inbound traffic
- **Terraform errors?**
  - Run `terraform validate` and `terraform plan` for diagnostics
- **Upgrading Atlantis or EKS?**
  - Update the relevant variables and re-apply Terraform

---

## USEFUL COMMANDS , Also Check Outputs.tf file
- Get your Atlantis URL with this command: Powershell

$atlantisUrl = kubectl get svc -n atlantis -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}'
echo "Atlantis URL: http://$atlantisUrl"
echo "GitHub Webhook URL: http://$atlantisUrl/events"

- Monitor Atlantis
# Check pod status
kubectl get pods -n atlantis

# View logs
kubectl logs -n atlantis statefulset/atlantis

# Check service status
kubectl get svc -n atlantis


---

## References
- [Atlantis Docs](https://www.runatlantis.io/docs/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [Helm Docs](https://helm.sh/docs/)
- [GitHub Webhooks](https://docs.github.com/en/developers/webhooks-and-events/webhooks/about-webhooks)
