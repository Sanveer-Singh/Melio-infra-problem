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

module "compute" {
  source = "./modules/compute"

  name_prefix           = local.name_prefix
  subnet_id             = module.networking.public_subnet_a_id
  frontend_sg_ids       = [module.security.frontend_security_group_id]
  backend_sg_ids        = [module.security.backend_security_group_id]
  instance_profile_name = module.security.instance_profile_name
  instance_type         = var.instance_type
  artifact_bucket       = local.artifact_bucket_name
  ssm_parameter_name    = module.security.ssm_parameter_name
  region                = var.region
}
