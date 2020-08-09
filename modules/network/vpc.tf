resource "aws_vpc" "vpc" {
  cidr_block                       = cidrsubnet(var.cidr_block, 0, 0)

  assign_generated_ipv6_cidr_block = true

  enable_dns_support               = true
  enable_dns_hostnames             = true

  tags = {
    Name                           = "vpc"
    Terraform                      = true
  }
}
