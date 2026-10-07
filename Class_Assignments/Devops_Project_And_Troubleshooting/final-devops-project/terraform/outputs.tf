output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "nat_gateway_id" {
  value = try(aws_nat_gateway.main[0].id, null)
}

output "node_security_group_id" {
  value = aws_security_group.nodes.id
}

output "eks_cluster_name" {
  value = try(aws_eks_cluster.main[0].name, "not created (create_eks = false)")
}

output "eks_role_arns" {
  value = { cluster = aws_iam_role.eks_cluster.arn, nodes = aws_iam_role.eks_nodes.arn }
}

output "backup_bucket" {
  value = aws_s3_bucket.backups.bucket
}

output "tf_lock_table" {
  value = aws_dynamodb_table.tf_locks.name
}

output "ssm_parameters" {
  value = sort([for p in aws_ssm_parameter.app_config : p.name])
}

output "db_secret_arn" {
  value = aws_secretsmanager_secret.db.arn
}

output "kubeconfig_command" {
  value = var.create_eks ? "aws eks update-kubeconfig --region ${var.aws_region} --name ${local.name}-eks" : "n/a - EKS disabled (LocalStack Community); the lab cluster is minikube"
}
