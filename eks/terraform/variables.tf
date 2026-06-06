variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "ecommerce-cluster"
}

variable "common_tags" {
  description = "Tags applied to all AWS resources"
  type        = map(string)
  default = {
    Project     = "ecommerce"
    ManagedBy   = "terraform"
    Environment = "dev"
  }
}
