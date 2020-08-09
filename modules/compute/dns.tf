# ---- SRV records ----
resource "aws_cloudwatch_event_rule" "compute_scaling" {
  name = "${var.name}-scaling"

  event_pattern = <<EOF
{
  "source": [
    "aws.autoscaling"
  ],
  "detail-type": [
    "EC2 Instance Launch Successful",
    "EC2 Instance Terminate Successful",
    "EC2 Instance Launch Unsuccessful",
    "EC2 Instance Terminate Successful",
    "EC2 Instance Terminate Unsuccessful",
    "EC2 Instance-launch Lifecycle Action",
    "EC2 Instance-terminate Lifecycle Action"
  ],
  "detail": {
    "AutoScalingGroupName": [
      "${aws_autoscaling_group.compute.name}"
    ]
  }
}
EOF
}

resource "aws_cloudwatch_event_target" "compute_scaling" {
  target_id = "${var.name}-scaling"
  rule = aws_cloudwatch_event_rule.compute_scaling.name
  arn = aws_lambda_function.compute_scaling.arn
}

resource "aws_cloudwatch_log_group" "compute_scaling" {
  name = "/aws/lambda/${var.name}-scaling"
  retention_in_days = 1

  tags = {
    Name = "${var.name}-scaling"
    Terraform = true
  }
}

resource "aws_iam_role" "compute_scaling" {
  name = "${var.name}-scaling"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": [
          "lambda.amazonaws.com"
        ]
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_lambda_permission" "compute_scaling" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.compute_scaling.arn
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.compute_scaling.arn
}


resource "aws_iam_role_policy" "compute_scaling" {
  name = "${var.name}-scaling"
  role = aws_iam_role.compute_scaling.name
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "ec2:Describe*",
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": "autoscaling:DescribeAutoScalingGroups",
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
              "route53:GetHostedZone",
              "route53:ChangeResourceRecordSets",
              "route53:ListResourceRecordSets"
             ],
            "Resource": "arn:aws:route53:::hostedzone/${var.zone_id}"
        },
        {
              "Effect": "Allow",
              "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
              ],
              "Resource": "*"
        }
    ]
}
EOF
}

data "archive_file" "compute_scaling" {
  type        = "zip"
  source_file = "${path.module}/dns.py"
  output_path = "${path.root}/.archive_files/compute_scaling.zip"
}

resource "aws_lambda_function" "compute_scaling" {
  lifecycle {
    ignore_changes = [
      last_modified
    ]
  }

  function_name = "${var.name}-scaling"
  role          = aws_iam_role.compute_scaling.arn
  handler       = "dns.lambda_handler"
  runtime       = "python3.8"
  timeout       = 60
  memory_size   = 256

  filename         = data.archive_file.compute_scaling.output_path
  source_code_hash = data.archive_file.compute_scaling.output_base64sha256

  environment {
    variables = {
      compute_name = var.name
      zone_id = var.zone_id
      srv_records = jsonencode(var.srv_records)
    }
  }

  depends_on = [aws_cloudwatch_log_group.compute_scaling]
}
