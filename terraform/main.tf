module "networking" {
  source = "./modules/networking"

  name_prefix         = local.name_prefix
  vpc_cidr            = "10.0.0.0/16"
  public_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
  availability_zones  = ["${var.region}a", "${var.region}b"]
}
