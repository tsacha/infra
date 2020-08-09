resource "aws_key_pair" "compute" {
  key_name = var.name
  public_key = var.public_key
}

resource "aws_launch_template" "compute" {
  name                   = var.name
  image_id               = data.aws_ami.ubuntu.id
  instance_type          = var.type
  key_name               = aws_key_pair.compute.key_name

  update_default_version = true

  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_size = var.ebs_size
    }
  }

  dynamic "instance_market_options" {
    for_each = var.spot ? [1] : []

    content {
      market_type = "spot"
    }
  }

  network_interfaces {
    ipv6_address_count = 1
    security_groups = [aws_security_group.compute.id]
  }

  iam_instance_profile {
    arn = aws_iam_instance_profile.compute.arn
  }

  tags = {
    Name = var.name
    Terraform = true
  }

  user_data = base64encode(data.template_file.cloud_config.rendered)
}
