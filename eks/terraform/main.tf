# =============================================================================
# main.tf — EKS Cluster + VPC using AWS provider
# This provisions the entire AWS infrastructure needed to run our app.
#
# Prerequisites:
#   - AWS CLI installed and configured: aws configure
#   - Terraform installed: https://developer.hashicorp.com/terraform/install
#   - kubectl installed
#
# Usage:
#   terraform init
#   terraform plan
#   terraform apply
# =============================================================================

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ---------------------------------------------------------------------------
# VPC — Virtual Private Cloud
# EKS nodes must live in a VPC. We create a dedicated one for isolation.
# ---------------------------------------------------------------------------
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.cluster_name}-vpc"
  cidr = "10.0.0.0/16"

  # Spread across 2 Availability Zones for high availability
  azs             = ["${var.aws_region}a", "${var.aws_region}b"]

  # Private subnets — EKS worker nodes go here (not directly accessible from internet)
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]

  # Public subnets — Load balancers go here (internet-facing)
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  # NAT Gateway — allows private subnet nodes to reach internet (for pulling images)
  enable_nat_gateway   = true
  single_nat_gateway   = true   # Use one NAT GW to save cost (use one per AZ in production)
  enable_dns_hostnames = true

  # These tags are REQUIRED by EKS and the AWS Load Balancer Controller
  # to know which subnets to place load balancers in
  public_subnet_tags = {
    "kubernetes.io/role/elb"                      = 1
    "kubernetes.io/cluster/${var.cluster_name}"   = "shared"
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"             = 1
    "kubernetes.io/cluster/${var.cluster_name}"   = "shared"
  }

  tags = var.common_tags
}

# ---------------------------------------------------------------------------
# EKS Cluster
# ---------------------------------------------------------------------------
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.30"

  vpc_id                         = module.vpc.vpc_id
  subnet_ids                     = module.vpc.private_subnets
  cluster_endpoint_public_access = true   # Allow kubectl from your laptop

  # Enable IRSA — lets pods assume IAM roles (needed for AWS Secrets Manager, S3, etc.)
  enable_irsa = true

  # EKS Managed Add-ons — AWS-maintained, auto-updated core components
  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true  # AWS VPC CNI — gives each pod a real VPC IP
    }
    aws-ebs-csi-driver = {
      most_recent              = true   # Required for EBS PersistentVolumes
      service_account_role_arn = aws_iam_role.ebs_csi_role.arn
    }
  }

  # ---------------------------------------------------------------------------
  # Node Groups — EC2 instances that run your pods
  # ---------------------------------------------------------------------------
  eks_managed_node_groups = {

    # General workloads — runs all application services
    general = {
      name           = "general-nodes"
      instance_types = ["t3.medium"]   # 2 vCPU, 4GB RAM — enough for our services
      min_size       = 2
      max_size       = 5
      desired_size   = 2

      # Spread across both AZs for HA
      subnet_ids = module.vpc.private_subnets

      labels = {
        node-type = "general"
      }

      tags = var.common_tags
    }

    # Storage workloads — dedicated node for Redis (mirrors our Kind taint setup)
    storage = {
      name           = "storage-nodes"
      instance_types = ["t3.small"]
      min_size       = 1
      max_size       = 2
      desired_size   = 1

      subnet_ids = [module.vpc.private_subnets[0]]

      labels = {
        node-type = "storage"
      }

      # Taint this node group — only pods with matching tolerations can land here
      taints = [
        {
          key    = "workload"
          value  = "storage"
          effect = "NO_SCHEDULE"
        }
      ]

      tags = var.common_tags
    }
  }

  tags = var.common_tags
}
