variable "aws_region" {
  description = "AWS region for every resource."
  type        = string
  default     = "ap-south-1"
}

variable "localstack_endpoint" {
  description = "LocalStack edge URL (only needed because we emulate AWS locally)."
  type        = string
  default     = "http://localhost:4566"
}

variable "project" {
  description = "Short name used as a prefix in every Name tag."
  type        = string
  default     = "ajij-cloud-tf"
}

variable "vpc_cidr" {
  description = "Address range of the VPC."
  type        = string
  default     = "10.10.0.0/16"
}

variable "public_subnet_cidr" {
  description = "Address range of the public subnet (must sit inside vpc_cidr)."
  type        = string
  default     = "10.10.1.0/24"
}

variable "instance_type" {
  description = "EC2 instance size."
  type        = string
  default     = "t3.micro"
}

variable "ssh_allowed_cidr" {
  description = "Who may SSH to the instance. Use your own IP/32, never 0.0.0.0/0."
  type        = string
  default     = "203.0.113.10/32"
}

variable "bucket_name" {
  description = "Globally unique name of the S3 bucket for app assets/logs."
  type        = string
}
