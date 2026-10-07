aws_region         = "ap-south-1"
project            = "ajij-cloud-tf"
vpc_cidr           = "10.10.0.0/16"
public_subnet_cidr = "10.10.1.0/24"
instance_type      = "t3.micro"
ssh_allowed_cidr   = "203.0.113.10/32" # documentation IP (RFC 5737); replace with your own /32
bucket_name        = "ajij-24bcs10103-app-assets"
