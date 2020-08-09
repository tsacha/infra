variable "name" {}

variable "arch" {
  default = "arm64"
}
variable "type" {}
variable "spot" {
  type = bool
  default = false
}

variable "vpc_id" {}

variable "asg_size" {}
variable "ebs_size" {
  default = 30
}
variable "cloud_config" {
  default = <<YAML
#cloud-config
package_update: true
package_upgrade: true
package_reboot_if_required: true
packages:
  - python3
output : { all : '| tee -a /var/log/cloud-init-output.log' }
YAML
}
variable "public_key" {}
variable "instance_profile_policy" {}

variable "zone_id" {}
variable "srv_records" {
  default = []
  type = list
}
