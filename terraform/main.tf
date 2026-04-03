module "networking" {
  source = "./modules/networking"

  name_prefix        = local.name_prefix
  availability_zones = ["${var.region}a", "${var.region}b"]
}

module "security" {
  source = "./modules/security"

  vpc_id                 = module.networking.vpc_id
  name_prefix            = local.name_prefix
  artifact_bucket_arn    = var.artifact_bucket_arn
  newsfeed_service_token = var.newsfeed_service_token
  ssh_cidr               = var.ssh_cidr
}
