resource "aws_iam_policy" "valheim_server" {
  name = "valheim-server"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket",
        "s3:GetBucketLocation",
        "s3:ListBucketMultipartUploads"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:PutObjectAcl",
        "s3:GetObject",
        "s3:GetBucketLocation",
        "s3:DeleteObject",
        "s3:ListMultipartUploadParts",
        "s3:AbortMultipartUpload"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

module "valheim_server" {
  source = "../compute"
  vpc_id = var.vpc_id
  zone_id = var.zone_id

  name = "valheim-server"
  spot = true
  asg_size = 0

  arch = "amd64"
  type = "t3a.medium"
  public_key = var.public_key

  instance_profile_policy = aws_iam_policy.valheim_server.arn

  cloud_config = <<YAML
#cloud-config
package_update: true
package_upgrade: true
package_reboot_if_required: true
packages:
  - python3
  - awscli
  - apt-transport-https
  - ca-certificates
  - curl
  - gnupg-agent
  - software-properties-common
runcmd:
  - curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
  - add-apt-repository "deb [arch=$(dpkg --print-architecture)] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
  - apt-get update -y
  - apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose
  - systemctl --now enable docker
  - aws s3 cp s3://tsacha/valheim/docker-compose.yml /opt
  - docker volume create opt_valheim-data
  - aws s3 sync s3://tsacha/valheim/ /var/lib/docker/volumes/opt_valheim-data/_data/Worlds/
  - chown ubuntu:ubuntu -R /var/lib/docker/volumes/opt_valheim-data/_data
  - echo '* * * * * /usr/bin/aws s3 sync /var/lib/docker/volumes/opt_valheim-data/_data/Worlds/ s3://tsacha/valheim/' > /var/spool/cron/crontabs/root
  - chmod 600 /var/spool/cron/crontabs/root
  - cd /opt && docker-compose up -d
output : { all : '| tee -a /var/log/cloud-init-output.log' }
YAML
}

resource "aws_security_group_rule" "valheim_tcp_input" {
  type            = "ingress"
  from_port       = 2456
  to_port         = 2456
  protocol        = "tcp"
  security_group_id = module.valheim_server.sg_id
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "valheim_udp_input" {
  type            = "ingress"
  from_port       = 2456
  to_port         = 2456
  protocol        = "udp"
  security_group_id = module.valheim_server.sg_id
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "valheim_tcp6_input" {
  type            = "ingress"
  from_port       = 2456
  to_port         = 2456
  protocol        = "tcp"
  security_group_id = module.valheim_server.sg_id
  ipv6_cidr_blocks = ["::/0"]
}

resource "aws_security_group_rule" "valheim_udp6_input" {
  type            = "ingress"
  from_port       = 2456
  to_port         = 2456
  protocol        = "udp"
  security_group_id = module.valheim_server.sg_id
  ipv6_cidr_blocks = ["::/0"]
}

resource "aws_security_group_rule" "valheim2_tcp_input" {
  type            = "ingress"
  from_port       = 2467
  to_port         = 2467
  protocol        = "tcp"
  security_group_id = module.valheim_server.sg_id
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "valheim2_udp_input" {
  type            = "ingress"
  from_port       = 2467
  to_port         = 2467
  protocol        = "udp"
  security_group_id = module.valheim_server.sg_id
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "valheim2_tcp6_input" {
  type            = "ingress"
  from_port       = 2467
  to_port         = 2467
  protocol        = "tcp"
  security_group_id = module.valheim_server.sg_id
  ipv6_cidr_blocks = ["::/0"]
}

resource "aws_security_group_rule" "valheim2_udp6_input" {
  type            = "ingress"
  from_port       = 2467
  to_port         = 2467
  protocol        = "udp"
  security_group_id = module.valheim_server.sg_id
  ipv6_cidr_blocks = ["::/0"]
}


resource "aws_route53_record" "valheim_server" {
  name = "valheim"
  type = "CNAME"
  zone_id = var.zone_id
  records = ["valheim-server.${var.zone_name}."]
  ttl = 300
}
