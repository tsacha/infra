variable "aws_region" {}

variable "cidr_block" {
  description = "CIDR for the whole VPC"
  default = "10.0.0.0/16"
}

variable "availability_zones" {
  type = map

  default = {
    eu-west-1      = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
    eu-west-3      = ["eu-west-3a", "eu-west-3b", "eu-west-3c"]
  }
}
