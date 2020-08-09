resource "aws_iam_policy" "etcd_cluster" {
  name = "etcd-cluster"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

module "etcd_cluster" {
  source = "../compute"

  vpc_id = var.vpc_id
  zone_id = var.zone_id
  srv_records = [
    {"label": "_etcd-client-ssl", "port": 2379, "proto": "tcp"},
    {"label": "_etcd-server-ssl", "port": 2380, "proto": "tcp"},
  ]

  name = "etcd-cluster"
  asg_size = 0

  arch = "amd64"
  spot = true
  type = "t3a.small"
  ebs_size = 8
  public_key = var.public_key

  instance_profile_policy = aws_iam_policy.etcd_cluster.arn

  cloud_config = <<YAML
#cloud-config
package_update: true
package_upgrade: true
package_reboot_if_required: true
packages:
  - etcd
write_files:
  - encoding: b64
    content: ${filebase64("${path.module}/files/default-etcd")}
    owner: root
    group: root
    path: /run/cloud-init/etcd
    permissions: '0644'
runcmd:
  - 'sed "s/{INSTANCE_ID}/$(ec2metadata  --instance-id)/g" /run/cloud-init/etcd > /etc/default/etcd'
output : { all : '| tee -a /var/log/cloud-init-output.log' }
YAML
}

resource "aws_security_group_rule" "etcd_input_from_etcd" {
  type            = "ingress"
  from_port       = 2379
  to_port         = 2380
  protocol        = "tcp"
  security_group_id = module.etcd_cluster.sg_id
  source_security_group_id = module.etcd_cluster.sg_id
}

resource "aws_security_group_rule" "etcd_input_from_controller" {
  type            = "ingress"
  from_port       = 2379
  to_port         = 2380
  protocol        = "tcp"
  security_group_id = module.etcd_cluster.sg_id
  source_security_group_id = module.k8s_controller.sg_id
}
