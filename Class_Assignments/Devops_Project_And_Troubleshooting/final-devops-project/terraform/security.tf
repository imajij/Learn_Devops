# Worker nodes: only traffic from inside the VPC; all egress (image pulls go through NAT).
resource "aws_security_group" "nodes" {
  name        = "${local.name}-nodes"
  description = "CampusDesk worker nodes"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "node-to-node and control plane traffic inside the VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${local.name}-nodes-sg" }
}

# Public load balancer for the Ingress controller: HTTP/HTTPS only.
resource "aws_security_group" "ingress_lb" {
  name        = "${local.name}-ingress-lb"
  description = "Internet-facing load balancer for the ingress controller"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }
  tags = { Name = "${local.name}-ingress-lb-sg" }
}
