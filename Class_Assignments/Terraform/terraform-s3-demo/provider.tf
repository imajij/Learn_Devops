terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # Pinned to 5.x on purpose: provider 6.x sends bucket tags inside the
      # CreateBucket call, which the LocalStack 4.0 community image ignores
      # (bucket ended up with tags = {}). On real AWS "~> 6.0" works fine.
      version = "~> 5.0"
    }
  }
}

# This provider talks to LocalStack (a local AWS emulator running in Docker),
# because no real AWS account was used for this homework.
# For real AWS: delete the access_key/secret_key, the skip_* flags,
# s3_use_path_style and the endpoints block, and log in with `aws configure`.
provider "aws" {
  region     = var.aws_region
  access_key = "test"
  secret_key = "test"

  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  s3_use_path_style           = true

  endpoints {
    s3  = var.localstack_endpoint
    sts = var.localstack_endpoint
  }

  default_tags {
    tags = {
      ManagedBy = "Terraform"
      Owner     = "ajij-uttam"
      Session   = "18"
    }
  }
}
