output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.main.id
}

output "public_subnet_id" {
  description = "ID of the public subnet."
  value       = aws_subnet.public.id
}

output "internet_gateway_id" {
  description = "ID of the internet gateway."
  value       = aws_internet_gateway.main.id
}

output "security_group_id" {
  description = "ID of the web security group."
  value       = aws_security_group.web.id
}

output "ami_id" {
  description = "AMI chosen by the data source."
  value       = data.aws_ami.ubuntu.id
}

output "ami_name" {
  description = "Name of that AMI."
  value       = data.aws_ami.ubuntu.name
}

output "instance_id" {
  description = "ID of the EC2 instance."
  value       = aws_instance.web.id
}

output "instance_public_ip" {
  description = "Public IP of the EC2 instance."
  value       = aws_instance.web.public_ip
}

output "instance_private_ip" {
  description = "Private IP of the EC2 instance."
  value       = aws_instance.web.private_ip
}

output "bucket_name" {
  description = "S3 bucket for app assets."
  value       = aws_s3_bucket.assets.bucket
}

output "instance_role_arn" {
  description = "IAM role attached to the instance."
  value       = aws_iam_role.ec2.arn
}
