resource "aws_autoscaling_group" "compute" {
  name_prefix = "${var.name}-asg"

  desired_capacity          = var.asg_size
  max_size                  = var.asg_size * 2
  min_size                  = 0
  wait_for_capacity_timeout = 0

  default_cooldown = 0

  health_check_grace_period = 0
  health_check_type         = "EC2"

  vpc_zone_identifier = data.aws_subnet_ids.public_subnets.ids

  enabled_metrics = [
    "GroupMinSize",
    "GroupMaxSize",
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupPendingInstances",
    "GroupStandbyInstances",
    "GroupTerminatingInstances",
    "GroupTotalInstances"
  ]

  launch_template {
    id      = aws_launch_template.compute.id
    version = aws_launch_template.compute.latest_version
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 0
    }
  }

  termination_policies = [
    "OldestLaunchConfiguration"
  ]

  tag {
    key = "Name"
    value = var.name
    propagate_at_launch = true
  }
  tag {
    key = "Terraform"
    value = true
    propagate_at_launch = true
  }
}
