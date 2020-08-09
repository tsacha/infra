data "aws_subnet_ids" "public_subnets" {
  vpc_id = var.vpc_id
  tags = {
    Type        = "public"
    Terraform   = true
  }
}

data "template_file" "cloud_config" {
  template = var.cloud_config
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners = ["099720109477"]
  filter {
    name = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-hirsute-21.04-${var.arch}-server-*"]
  }
}
