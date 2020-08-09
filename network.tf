module "network" {
  source = "./modules/network"

  aws_region = var.aws_region
}
