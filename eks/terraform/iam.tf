# =============================================================================
# iam.tf — IAM Roles for Service Accounts (IRSA)
#
# IRSA is an EKS-specific feature that lets a Kubernetes ServiceAccount
# assume an AWS IAM Role. This means pods get AWS permissions without
# storing AWS credentials as Secrets.
#
# How it works:
#   Pod → ServiceAccount → IAM Role → AWS permissions
#   (K8s identity)        (AWS identity)
# =============================================================================

# ---------------------------------------------------------------------------
# EBS CSI Driver IAM Role
# The EBS CSI driver needs permission to create/attach/delete EBS volumes.
# Without this, PersistentVolumeClaims will stay in Pending forever.
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "ebs_csi_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }

    principals {
      identifiers = [module.eks.oidc_provider_arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "ebs_csi_role" {
  name               = "${var.cluster_name}-ebs-csi-role"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_assume_role.json
  tags               = var.common_tags
}

resource "aws_iam_role_policy_attachment" "ebs_csi_policy" {
  role       = aws_iam_role.ebs_csi_role.name
  # AWS managed policy that grants all needed EBS permissions
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# ---------------------------------------------------------------------------
# AWS Load Balancer Controller IAM Role
# The ALB controller needs permission to create/manage ALBs and Target Groups.
# ---------------------------------------------------------------------------
resource "aws_iam_policy" "alb_controller" {
  name        = "${var.cluster_name}-alb-controller-policy"
  description = "IAM policy for AWS Load Balancer Controller"

  # This is the official policy from AWS docs
  policy = file("${path.module}/alb-controller-policy.json")
}

data "aws_iam_policy_document" "alb_controller_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }

    principals {
      identifiers = [module.eks.oidc_provider_arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "alb_controller" {
  name               = "${var.cluster_name}-alb-controller-role"
  assume_role_policy = data.aws_iam_policy_document.alb_controller_assume_role.json
  tags               = var.common_tags
}

resource "aws_iam_role_policy_attachment" "alb_controller" {
  role       = aws_iam_role.alb_controller.name
  policy_arn = aws_iam_policy.alb_controller.arn
}

# ---------------------------------------------------------------------------
# Output the ALB controller role ARN — needed when installing the controller
# ---------------------------------------------------------------------------
output "alb_controller_role_arn" {
  value = aws_iam_role.alb_controller.arn
}

output "ebs_csi_role_arn" {
  value = aws_iam_role.ebs_csi_role.arn
}
