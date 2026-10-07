terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # 5.x because provider 6.x sends S3 tags inside CreateBucket, which the
      # LocalStack 4.0 community image ignores. On real AWS "~> 6.0" is fine.
      version = "~> 5.0"
    }
  }
}
