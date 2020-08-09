resource "aws_iam_policy" "k8s_controller" {
  name = "k8s-controller"
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

module "k8s_controller" {
  source = "../compute"

  vpc_id = var.vpc_id
  zone_id = var.zone_id

  name = "k8s-controller"
  asg_size = 0

  arch = "amd64"
  spot = true
  type = "t3a.small"
  ebs_size = 8
  public_key = var.public_key

  instance_profile_policy = aws_iam_policy.k8s_controller.arn

  cloud_config = <<YAML
#cloud-config
package_update: true
package_upgrade: true
package_reboot_if_required: true
packages:
  - ca-certificates
  - curl
write_files:
  - encoding: b64
    content: ${filebase64("${path.module}/files/kube-apiserver.service")}
    owner: root
    group: root
    path: /run/cloud-init/kube-apiserver.service
    permissions: '0644'
  - encoding: b64
    content: ${filebase64("${path.module}/files/encryption-config.yaml")}
    owner: root
    group: root
    path: /run/cloud-init/encryption-config.yaml
    permissions: '0644'
  - encoding: b64
    content: ${filebase64("${path.module}/files/kube-controller-manager.service")}
    owner: root
    group: root
    path: /etc/systemd/system/kube-controller-manager.service
    permissions: '0644'
  - encoding: b64
    content: ${filebase64("${path.module}/files/kube-scheduler.service")}
    owner: root
    group: root
    path: /etc/systemd/system/kube-scheduler.service
    permissions: '0644'
  - encoding: b64
    content: ${filebase64("${path.module}/files/kube-scheduler.yaml")}
    owner: root
    group: root
    path: /var/lib/kubernetes/kube-scheduler.yaml
    permissions: '0644'
runcmd:
  - curl -fsSLo /usr/local/bin/kube-apiserver https://storage.googleapis.com/kubernetes-release/release/v1.21.0/bin/linux/amd64/kube-apiserver
  - curl -fsSLo /usr/local/bin/kube-controller-manager https://storage.googleapis.com/kubernetes-release/release/v1.21.0/bin/linux/amd64/kube-controller-manager
  - curl -fsSLo /usr/local/bin/kube-scheduler https://storage.googleapis.com/kubernetes-release/release/v1.21.0/bin/linux/amd64/kube-scheduler
  - curl -fsSLo /usr/local/bin/kubectl https://storage.googleapis.com/kubernetes-release/release/v1.21.0/bin/linux/amd64/kubectl
  - chmod +x /usr/local/bin/*
output : { all : '| tee -a /var/log/cloud-init-output.log' }
YAML
}

resource "aws_security_group_rule" "controller_internal" {
  type            = "ingress"
  from_port       = 0
  to_port         = 0
  protocol        = "-1"
  security_group_id = module.k8s_controller.sg_id
  source_security_group_id = module.k8s_controller.sg_id
}


resource "aws_security_group_rule" "controller_input_api" {
  type            = "ingress"
  from_port       = 6443
  to_port         = 6443
  protocol        = "tcp"
  security_group_id = module.k8s_controller.sg_id
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "controller_input6_api" {
  type            = "ingress"
  from_port       = 6443
  to_port         = 6443
  protocol        = "tcp"
  security_group_id = module.k8s_controller.sg_id
  ipv6_cidr_blocks = ["::/0"]
}
