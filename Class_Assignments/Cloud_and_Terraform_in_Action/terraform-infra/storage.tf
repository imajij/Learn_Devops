resource "aws_s3_bucket" "assets" {
  bucket        = var.bucket_name
  force_destroy = true

  tags = { Name = var.bucket_name }
}

resource "aws_s3_bucket_versioning" "assets" {
  bucket = aws_s3_bucket.assets.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "assets" {
  bucket                  = aws_s3_bucket.assets.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.assets.id
  key          = "site/index.html"
  content      = "<h1>Hello from ${var.project}</h1><p>Deployed with Terraform by Ajij Uttam (24bcs10103)</p>\n"
  content_type = "text/html"
}
