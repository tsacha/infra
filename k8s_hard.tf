module "k8s_hard" {
  source = "./modules/k8s-hard"

  vpc_id = module.network.vpc_id

  zone_id = aws_route53_zone.tech.zone_id
  zone_name = "tsacha.fr"

  public_key = data.local_file.sacha_legacy.content
}
