resource "aws_iam_role" "compute" {
  name = var.name

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": [
          "ec2.amazonaws.com"
        ]
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "compute" {
  name = "${var.name}-instance-profile"
  role = aws_iam_role.compute.name
}

resource "aws_iam_role_policy_attachment" "discord_bot" {
  role    = aws_iam_role.compute.name
  policy_arn = var.instance_profile_policy
}
