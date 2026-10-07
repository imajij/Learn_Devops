# Supporting services for the application.

# S3 bucket for nightly PostgreSQL dumps (private, versioned, encrypted).
resource "aws_s3_bucket" "backups" {
  bucket        = "${local.name}-db-backups"
  force_destroy = true # lab only: allow `terraform destroy` with objects inside
}

resource "aws_s3_bucket_versioning" "backups" {
  bucket = aws_s3_bucket.backups.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "backups" {
  bucket = aws_s3_bucket.backups.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

resource "aws_s3_bucket_public_access_block" "backups" {
  bucket                  = aws_s3_bucket.backups.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Skipped on LocalStack: AWS provider 5.x waits for the response header
# x-amz-transition-default-minimum-object-size on GET ?lifecycle; LocalStack 4.0 does not return it, so the
# create times out after 3 minutes (seen in the first two applies, see lab/08a-*).
resource "aws_s3_bucket_lifecycle_configuration" "backups" {
  count  = local.use_localstack ? 0 : 1
  bucket = aws_s3_bucket.backups.id
  rule {
    id     = "expire-old-dumps"
    status = "Enabled"
    filter { prefix = "pg-dumps/" }
    expiration { days = 30 }
    noncurrent_version_expiration { noncurrent_days = 7 }
  }
}

# DynamoDB table used for Terraform state locking (see the commented backend in versions.tf).
resource "aws_dynamodb_table" "tf_locks" {
  name         = "${local.name}-tf-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }
}

# Non-secret app settings in SSM Parameter Store (source for the Helm values / ConfigMap).
resource "aws_ssm_parameter" "app_config" {
  for_each = {
    APP_ENV = var.environment
    DB_NAME = "campusdesk"
    DB_PORT = "5432"
  }
  name  = "/campusdesk/${var.environment}/${each.key}"
  type  = "String"
  value = each.value
}

# Database credentials live in Secrets Manager. Only the secret "container" is created here;
# the value is put in out-of-band (never in Terraform code or state).
resource "aws_secretsmanager_secret" "db" {
  name                    = "campusdesk/${var.environment}/db"
  description             = "CampusDesk PostgreSQL credentials"
  recovery_window_in_days = 0
}

# Central log group for the application (Fluent Bit / CloudWatch agent would ship pod logs here).
resource "aws_cloudwatch_log_group" "app" {
  name              = "/campusdesk/${var.environment}/app"
  retention_in_days = 14
}
