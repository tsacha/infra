output "asg_name" {
  value = aws_autoscaling_group.compute.name
}

output "sg_id" {
  value = aws_security_group.compute.id
}
