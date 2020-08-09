resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = cidrsubnet(var.cidr_block, 8, count.index)

  ipv6_cidr_block = cidrsubnet(aws_vpc.vpc.ipv6_cidr_block, 8, count.index)
  assign_ipv6_address_on_creation = true

  availability_zone       = element(var.availability_zones[var.aws_region], count.index)
  map_public_ip_on_launch = true
  count                   = length(var.availability_zones[var.aws_region])

  tags = {
    Name        = "${element(var.availability_zones[var.aws_region], count.index)}-public"
    Type        = "public"
    Terraform   = true
  }
}

resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name        = "internet-gateway"
    Terraform   = true
  }
}

resource "aws_route_table" "public_routetable" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
  }

  tags = {
    Name        = "public-routetable"
    Terraform   = true
  }
}

resource "aws_route_table_association" "public_routing_table" {
  subnet_id      = element(aws_subnet.public_subnet.*.id, count.index)
  route_table_id = aws_route_table.public_routetable.id
  count          = length(var.availability_zones[var.aws_region])
}
