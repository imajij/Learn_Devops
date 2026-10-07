# EKS control plane + managed node group in the private subnets.
# Gated by var.create_eks: EKS is a LocalStack Pro feature, so the lab plans/applies it with
# create_eks=false (0 instances). On real AWS run with -var create_eks=true.
resource "aws_eks_cluster" "main" {
  count    = var.create_eks ? 1 : 0
  name     = "${local.name}-eks"
  version  = var.cluster_version
  role_arn = aws_iam_role.eks_cluster.arn

  vpc_config {
    subnet_ids              = concat(aws_subnet.private[*].id, aws_subnet.public[*].id)
    security_group_ids      = [aws_security_group.nodes.id]
    endpoint_public_access  = true
    endpoint_private_access = true
  }

  depends_on = [aws_iam_role_policy_attachment.eks_cluster]
}

resource "aws_eks_node_group" "main" {
  count           = var.create_eks ? 1 : 0
  cluster_name    = aws_eks_cluster.main[0].name
  node_group_name = "${local.name}-nodes"
  node_role_arn   = aws_iam_role.eks_nodes.arn
  subnet_ids      = aws_subnet.private[*].id
  instance_types  = var.node_instance_types

  scaling_config {
    min_size     = var.node_scaling.min
    desired_size = var.node_scaling.desired
    max_size     = var.node_scaling.max
  }

  depends_on = [aws_iam_role_policy_attachment.eks_nodes]
}
