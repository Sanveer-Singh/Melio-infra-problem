module "networking" {
  source = "./modules/networking"

  name_prefix         = local.name_prefix
  vpc_cidr            = "10.0.0.0/16"
  public_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
  availability_zones  = ["${var.region}a", "${var.region}b"]
}

module "security" {
  source = "./modules/security"

  vpc_id                 = module.networking.vpc_id
  name_prefix            = local.name_prefix
  artifact_bucket_arn    = var.artifact_bucket_arn
  newsfeed_service_token = var.newsfeed_service_token
  ssh_cidr               = var.ssh_cidr
}
