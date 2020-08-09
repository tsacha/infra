resource "aws_security_group" "compute" {
  name        = "${var.name}-sg"
  description = "${var.name} - Security Group"
  vpc_id      = var.vpc_id

  tags = {
    Name        = var.name
    Terraform   = true
  }
}

resource "aws_security_group_rule" "ssh_input" {
  type            = "ingress"
  from_port       = 22
  to_port         = 22
  protocol        = "tcp"
  security_group_id = aws_security_group.compute.id
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "ssh_input6" {
  type            = "ingress"
  from_port       = 22
  to_port         = 22
  protocol        = "tcp"
  security_group_id = aws_security_group.compute.id
  ipv6_cidr_blocks = ["::/0"]
}

resource "aws_security_group_rule" "output" {
  type            = "egress"
  from_port       = 0
  to_port         = 0
  protocol        = "-1"
  security_group_id = aws_security_group.compute.id
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "output6" {
  type            = "egress"
  from_port       = 0
  to_port         = 0
  protocol        = "-1"
  security_group_id = aws_security_group.compute.id
  ipv6_cidr_blocks = ["::/0"]
}
