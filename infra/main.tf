module "vpc" {
  source                  = "./modules/vpc"
  name                    = var.name
  env                     = var.env
}