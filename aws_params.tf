variable "aws_region" {
  description = "Amazon Region"
  default     = "eu-west-3"
}

data "aws_region" "current" {}

provider "aws" {
  profile = "sacha"
  region  = var.aws_region
}

provider "aws" {
  profile = "sacha"
  alias   = "virginia"
  region  = "us-east-1"
}

terraform {
  backend "s3" {
    key            = "terraform/common"
    profile        = "sacha"
    region         = "eu-west-3"
    bucket         = "tsacha"
    dynamodb_table = "terraform-state-locking"
    encrypt        = true
  }
}
