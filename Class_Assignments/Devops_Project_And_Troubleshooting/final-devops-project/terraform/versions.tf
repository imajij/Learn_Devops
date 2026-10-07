terraform {
  required_version = ">= 1.7.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  # Local state for the LocalStack lab. For a team / real AWS use a remote backend, e.g.:
  # backend "s3" {
  #   bucket         = "campusdesk-tfstate-<account-id>"
  #   key            = "infra/terraform.tfstate"
  #   region         = "ap-south-1"
  #   dynamodb_table = "campusdesk-tf-locks"
  # }
}
