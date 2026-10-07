variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "environment" {
  description = "Environment name used in resource names and tags"
  type        = string
  default     = "dev"
}

variable "localstack_endpoint" {
  description = "LocalStack URL. Set to \"\" to talk to real AWS."
  type        = string
  default     = "http://localhost:4577"
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC"
  type        = string
  default     = "10.20.0.0/16"
}

variable "availability_zones" {
  description = "Two AZs: one public + one private subnet in each"
  type        = list(string)
  default     = ["ap-south-1a", "ap-south-1b"]
}

variable "enable_nat_gateway" {
  description = "Single NAT gateway so private subnets (worker nodes) can pull images"
  type        = bool
  default     = true
}

variable "create_eks" {
  description = "Create the EKS cluster + node group. EKS is not in LocalStack Community, so false for the lab."
  type        = bool
  default     = false
}

variable "cluster_version" {
  description = "Kubernetes version for EKS"
  type        = string
  default     = "1.33"
}

variable "node_instance_types" {
  description = "Instance types of the managed node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_scaling" {
  description = "min / desired / max nodes"
  type        = object({ min = number, desired = number, max = number })
  default     = { min = 2, desired = 2, max = 4 }
}
