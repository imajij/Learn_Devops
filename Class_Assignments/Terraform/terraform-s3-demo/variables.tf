variable "aws_region" {
  description = "AWS region where the bucket is created."
  type        = string
  default     = "ap-south-1"
}

variable "localstack_endpoint" {
  description = "URL of the LocalStack edge port (only used because we run against LocalStack)."
  type        = string
  default     = "http://localhost:4566"
}

variable "bucket_name" {
  description = "Globally unique S3 bucket name (lowercase, 3-63 chars)."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.bucket_name))
    error_message = "Bucket name must be 3-63 chars of lowercase letters, digits, dots and hyphens."
  }
}

variable "environment" {
  description = "Environment tag (dev / stage / prod)."
  type        = string
  default     = "dev"
}

variable "enable_versioning" {
  description = "Keep old versions of every object."
  type        = bool
  default     = true
}
