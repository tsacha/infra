resource "aws_iam_policy" "k8s_worker" {
  name = "k8s-worker"
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
    },
    {
      "Sid": "",
      "Effect": "Allow",
      "Action": [
        "ecr:*"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:AssignPrivateIpAddresses",
        "ec2:AttachNetworkInterface",
        "ec2:CreateNetworkInterface",
        "ec2:DeleteNetworkInterface",
        "ec2:DescribeInstances",
        "ec2:DescribeInstanceTypes",
        "ec2:DescribeTags",
        "ec2:DescribeNetworkInterfaces",
        "ec2:DetachNetworkInterface",
        "ec2:ModifyNetworkInterfaceAttribute",
        "ec2:UnassignPrivateIpAddresses"
      ],
      "Resource": "*"
    },
    {
       "Effect": "Allow",
       "Action": [
          "ec2:CreateTags"
        ],
        "Resource": ["arn:aws:ec2:*:*:network-interface/*"]
    }
  ]
}
EOF
}

module "k8s_worker" {
  source = "../compute"

  vpc_id = var.vpc_id
  zone_id = var.zone_id

  name = "k8s-worker"
  asg_size = 0

  arch = "amd64"
  spot = true
  type = "t3a.medium"
  ebs_size = 8
  public_key = var.public_key

  instance_profile_policy = aws_iam_policy.k8s_worker.arn

  cloud_config = <<YAML
#cloud-config
package_update: true
package_upgrade: true
package_reboot_if_required: true
packages:
  - python3
  - python3-pip
  - awscli
  - jq
  - apt-transport-https
  - ca-certificates
  - curl
  - socat
  - conntrack
  - ipset
write_files:
  - encoding: b64
    content: ${filebase64("${path.module}/files/modules-containerd")}
    owner: root
    group: root
    path: /etc/modules-load.d/containerd.conf
    permissions: '0644'
    permissions: '0644'
  - encoding: b64
    content: ${filebase64("${path.module}/files/99-kubernetes-cri.conf")}
    owner: root
    group: root
    path: /etc/sysctl.d/99-kubernetes-cri.conf
    permissions: '0644'
  - encoding: b64
    content: ${filebase64("${path.module}/files/10-kubelet.conf")}
    owner: root
    group: root
    path: /run/cloud-init/10-kubelet.conf
    permissions: '0644'
  - encoding: b64
    content: ${filebase64("${path.module}/files/kubelet.yaml")}
    owner: root
    group: root
    path: /run/cloud-init/kubelet.yaml
    permissions: '0644'
  - encoding: b64
    content: ${filebase64("${path.module}/files/kube-proxy-config.yaml")}
    owner: root
    group: root
    path: /var/lib/kube-proxy/kube-proxy-config.yaml
    permissions: '0644'
  - encoding: b64
    content: ${filebase64("${path.module}/files/10-bridge.conf")}
    owner: root
    group: root
    path: /run/cloud-init/10-bridge.conf
    permissions: '0644'
  - encoding: b64
    content: ${filebase64("${path.module}/files/99-loopback.conf")}
    owner: root
    group: root
    path: /etc/cni/net.d/99-loopback.conf
    permissions: '0644'
  - encoding: b64
    content: ${filebase64("${path.module}/files/kube-proxy.service")}
    owner: root
    group: root
    path: /run/cloud-init/kube-proxy.service
    permissions: '0644'
runcmd:
  - modprobe br_netfilter
  - modprobe overlay
  - sysctl --system
  - curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
  - 'echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list'
  - curl -fsSLo /usr/local/bin/kube-proxy https://storage.googleapis.com/kubernetes-release/release/v1.21.0/bin/linux/amd64/kube-proxy
  - chmod +x /usr/local/bin/*
  - apt -y update
  - apt -y install kubelet kubectl containerd runc kubernetes-cni cri-tools
  - mkdir -p /etc/containerd /var/lib/kubernetes /var/lib/kubelet /var/lib/kubelet/pki /etc/systemd/system/kubelet.service.d
  - 'containerd config default | sudo tee /etc/containerd/config.toml'
  - 'sed -E -i "s/(\s*)(\[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options\])/\1\2\n\1  SystemdCgroup = true/" /etc/containerd/config.toml'
  - systemctl daemon-reload
  - systemctl restart containerd kubelet
output : { all : '| tee -a /var/log/cloud-init-output.log' }
YAML
}

resource "aws_security_group_rule" "worker_from_controller" {
  type            = "ingress"
  from_port       = 0
  to_port         = 0
  protocol        = "-1"
  security_group_id = module.k8s_worker.sg_id
  source_security_group_id = module.k8s_controller.sg_id
}

resource "aws_security_group_rule" "worker_internal" {
  type            = "ingress"
  from_port       = 0
  to_port         = 0
  protocol        = "-1"
  security_group_id = module.k8s_worker.sg_id
  source_security_group_id = module.k8s_worker.sg_id
}
