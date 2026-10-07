# 1. The bucket itself
resource "aws_s3_bucket" "demo" {
  bucket        = var.bucket_name
  force_destroy = true # lets `terraform destroy` delete a bucket that still has objects

  tags = {
    Name        = var.bucket_name
    Environment = var.environment
  }
}

# 2. Versioning (separate resource since AWS provider v4)
resource "aws_s3_bucket_versioning" "demo" {
  bucket = aws_s3_bucket.demo.id

  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Suspended"
  }
}

# 3. Default encryption at rest with S3-managed keys (SSE-S3 / AES256)
resource "aws_s3_bucket_server_side_encryption_configuration" "demo" {
  bucket = aws_s3_bucket.demo.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# 4. Block every form of public access
resource "aws_s3_bucket_public_access_block" "demo" {
  bucket = aws_s3_bucket.demo.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 5. A small object so the bucket is not empty
resource "aws_s3_object" "hello" {
  bucket       = aws_s3_bucket.demo.id
  key          = "hello.txt"
  content      = "Hello from Terraform! Created by Ajij Uttam (24bcs10103).\n"
  content_type = "text/plain"
}
