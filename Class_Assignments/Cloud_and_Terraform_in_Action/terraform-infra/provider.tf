# LocalStack (AWS emulator in Docker on localhost:4566) stands in for AWS here.
# For real AWS keep only `region` and `default_tags`: remove the dummy keys,
# the skip_* flags, s3_use_path_style and the endpoints block, then
# authenticate with `aws configure` / `aws sso login` or an IAM role.
provider "aws" {
  region     = var.aws_region
  access_key = "test"
  secret_key = "test"

  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  s3_use_path_style           = true

  endpoints {
    ec2 = var.localstack_endpoint
    iam = var.localstack_endpoint
    s3  = var.localstack_endpoint
    sts = var.localstack_endpoint
  }

  default_tags {
    tags = {
      Project   = var.project
      Owner     = "ajij-uttam"
      ManagedBy = "Terraform"
      Session   = "19"
    }
  }
}
