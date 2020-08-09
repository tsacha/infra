resource "aws_iam_policy" "discord_bot" {
  name = "discord-bot"
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

module "discord_bot" {
  source = "../compute"

  vpc_id = var.vpc_id
  zone_id = var.zone_id

  name = "discord-bot"
  asg_size = 0

  arch = "amd64"
  spot = true
  type = "t3a.nano"
  ebs_size = 8
  public_key = var.public_key

  instance_profile_policy = aws_iam_policy.discord_bot.arn

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
write_files:
  - encoding: b64
    content: ${filebase64("${path.module}/files/ssh_config")}
    owner: root
    group: root
    path: /root/.ssh/config
    permissions: '0644'
runcmd:
  - AWS_DEFAULT_REGION=eu-west-3 aws secretsmanager get-secret-value --secret-id tsacha | jq  -r '.SecretString' | jq -r '.deploy_key' | base64 -d > /root/.ssh/deploy_key
  - AWS_DEFAULT_REGION=eu-west-3 aws secretsmanager get-secret-value --secret-id tsacha | jq  -r '.SecretString' | jq -r '"DISCORD_TOKEN=" + .discord_bot' > /root/.discord_token
  - chmod 400 /root/.ssh/deploy_key
  - git clone git@github.com:tsacha/kkkt-discord.git /opt/kkkt-discord
  - pip3 install -r /opt/kkkt-discord/requirements.txt
  - ln /opt/kkkt-discord/src/kkkt_discord/systemd.unit /etc/systemd/system/kkkt-discord.service
  - systemctl daemon-reload
  - systemctl enable kkkt-discord
  - systemctl start kkkt-discord
output : { all : '| tee -a /var/log/cloud-init-output.log' }
YAML
}
