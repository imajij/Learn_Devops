# Newest Ubuntu amd64 server image published by Canonical (owner 099720109477).
# The same lookup works on real AWS and on LocalStack's built-in AMI catalogue.
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd*/ubuntu-*-amd64-server-*"]
  }
}

resource "aws_instance" "web" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2.name

  # On real AWS this installs nginx and serves the page stored in S3.
  # (LocalStack's EC2 is an API mock, so the script is stored but not executed.)
  user_data = <<-EOT
    #!/bin/bash
    apt-get update -y && apt-get install -y nginx awscli
    aws s3 cp s3://${aws_s3_bucket.assets.bucket}/site/index.html /var/www/html/index.html
    systemctl enable --now nginx
  EOT

  root_block_device {
    volume_size = 8
    volume_type = "gp3"
  }

  # Explicit dependency: the instance gets a public IP, which is useless until
  # the IGW + route exist. Terraform cannot see that from references alone.
  depends_on = [aws_route_table_association.public]

  tags = { Name = "${var.project}-web" }
}
