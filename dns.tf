resource "aws_route53_zone" "tech" {
  name = "tsacha.fr"
}

resource "null_resource" "updatens-domain" {
  triggers = {
    nameservers = join(",", aws_route53_zone.tech.name_servers)
  }

  provisioner "local-exec" {
    command = "aws route53domains update-domain-nameservers --region us-east-1 --domain-name ${aws_route53_zone.tech.name} --nameservers Name=${aws_route53_zone.tech.name_servers.0} Name=${aws_route53_zone.tech.name_servers.1} Name=${aws_route53_zone.tech.name_servers.2} Name=${aws_route53_zone.tech.name_servers.3}"
    environment = {
      AWS_DEFAULT_PROFILE = "sacha"
    }
  }
}
