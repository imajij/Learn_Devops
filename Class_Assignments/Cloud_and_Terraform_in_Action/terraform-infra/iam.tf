# Role the EC2 instance assumes, so it can read the bucket WITHOUT any access keys on disk.
data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2" {
  name               = "${var.project}-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

# Least privilege: list + read only, and only on this one bucket.
data "aws_iam_policy_document" "read_assets" {
  statement {
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.assets.arn]
  }
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.assets.arn}/*"]
  }
}

resource "aws_iam_role_policy" "read_assets" {
  name   = "read-app-assets"
  role   = aws_iam_role.ec2.id
  policy = data.aws_iam_policy_document.read_assets.json
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${var.project}-ec2-profile"
  role = aws_iam_role.ec2.name
}
