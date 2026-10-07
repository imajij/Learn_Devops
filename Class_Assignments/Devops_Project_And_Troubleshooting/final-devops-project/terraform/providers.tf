# One provider block for both targets:
#   * LocalStack (default for this lab): localstack_endpoint = "http://localhost:4577", dummy "test" keys
#   * real AWS: localstack_endpoint = "" and the normal AWS credential chain
locals {
  use_localstack = var.localstack_endpoint != ""
}

provider "aws" {
  region = var.aws_region

  access_key                  = local.use_localstack ? "test" : null
  secret_key                  = local.use_localstack ? "test" : null
  skip_credentials_validation = local.use_localstack
  skip_metadata_api_check     = local.use_localstack
  skip_requesting_account_id  = local.use_localstack
  s3_use_path_style           = local.use_localstack

  dynamic "endpoints" {
    for_each = local.use_localstack ? [var.localstack_endpoint] : []
    content {
      ec2            = endpoints.value
      eks            = endpoints.value
      iam            = endpoints.value
      sts            = endpoints.value
      s3             = endpoints.value
      dynamodb       = endpoints.value
      ssm            = endpoints.value
      secretsmanager = endpoints.value
      cloudwatchlogs = endpoints.value
    }
  }

  default_tags {
    tags = {
      Project     = "campusdesk"
      Environment = var.environment
      Owner       = "ajij-uttam"
      ManagedBy   = "terraform"
    }
  }
}
