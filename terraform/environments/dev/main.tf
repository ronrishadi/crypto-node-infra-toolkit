module "vpc" {
  source = "../../modules/vpc"

  name               = var.name
  availability_zone  = var.availability_zone
  ssh_allowed_cidrs  = var.ssh_allowed_cidrs
  node_ingress_ports = var.node_ingress_ports
  tags               = var.tags
}

module "backups" {
  source = "../../modules/backups"

  bucket_name                    = var.backup_bucket_name
  enable_lifecycle_configuration = var.enable_lifecycle_configuration
  tags                           = var.tags
}

module "node" {
  source = "../../modules/node-instance"

  name              = var.name
  subnet_id         = module.vpc.public_subnet_id
  security_group_id = module.vpc.node_security_group_id
  backup_bucket_arn = module.backups.bucket_arn
  instance_type     = var.instance_type
  ami_id            = var.ami_id
  ssh_key_name      = var.ssh_key_name
  create_instance   = var.create_compute
  tags              = var.tags
}

# Monitoring alarms are keyed to a live instance id, so they only exist when
# compute does.
module "monitoring" {
  source = "../../modules/monitoring"
  count  = var.create_compute ? 1 : 0

  name        = var.name
  instance_id = module.node.instance_id
  tags        = var.tags
}
