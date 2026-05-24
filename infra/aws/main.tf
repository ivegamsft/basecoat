locals {
  common_tags = merge(
    var.tags,
    {
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "Terraform"
      CreatedAt   = timestamp()
    }
  )

  aws_tags = merge(local.common_tags, {
    Region = var.aws_primary_region
  })

  azure_tags = merge(local.common_tags, {
    Location = var.azure_location_primary
  })

  gcp_labels = {
    environment = var.environment
    project     = replace(var.project_name, "-", "_")
    managed_by  = "terraform"
  }
}

module "aws_networking" {
  source = "./modules/networking"

  project_name         = var.project_name
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  private_subnets_cidr = var.private_subnets_cidr
  public_subnets_cidr  = var.public_subnets_cidr
  tags                 = local.aws_tags
  providers = {
    aws = aws
  }
}

module "aws_security" {
  source = "./modules/security"

  project_name = var.project_name
  environment  = var.environment
  vpc_id       = module.aws_networking.vpc_id
  tags         = local.aws_tags
  providers = {
    aws = aws
  }
}

module "aws_database" {
  source = "./modules/database"

  project_name                = var.project_name
  environment                 = var.environment
  database_subnet_group_name  = module.aws_networking.database_subnet_group_name
  security_group_id           = module.aws_security.database_security_group_id
  engine_version              = var.database_engine_version
  instance_class              = var.database_instance_class
  allocated_storage           = var.database_allocated_storage
  backup_retention_days       = var.database_backup_retention_days
  multi_az                    = var.database_multi_az
  enable_read_replicas        = var.enable_read_replicas
  enable_encryption_at_rest   = var.enable_encryption_at_rest
  tags                        = local.aws_tags
  providers = {
    aws = aws
  }

  depends_on = [module.aws_networking]
}

module "aws_compute" {
  source = "./modules/compute"

  project_name           = var.project_name
  environment            = var.environment
  vpc_subnets            = module.aws_networking.private_subnet_ids
  security_group_ids     = [module.aws_security.application_security_group_id]
  instance_type          = var.compute_instance_type
  min_size               = var.compute_min_size
  max_size               = var.compute_max_size
  desired_capacity       = var.compute_desired_capacity
  enable_cost_optimization = var.enable_cost_optimization
  spot_instance_pools    = var.spot_instance_pools
  tags                   = local.aws_tags
  providers = {
    aws = aws
  }

  depends_on = [module.aws_networking, module.aws_security]
}

module "aws_caching" {
  source = "./modules/caching"

  project_name               = var.project_name
  environment                = var.environment
  subnet_group_name          = module.aws_networking.cache_subnet_group_name
  security_group_id          = module.aws_security.cache_security_group_id
  cache_node_type            = var.cache_instance_type
  num_cache_nodes            = var.cache_num_cache_nodes
  automatic_failover_enabled = var.cache_automatic_failover_enabled
  enable_encryption_at_rest  = var.enable_encryption_at_rest
  tags                       = local.aws_tags
  providers = {
    aws = aws
  }

  depends_on = [module.aws_networking]
}

module "aws_storage" {
  source = "./modules/storage"

  project_name               = var.project_name
  environment                = var.environment
  enable_encryption_at_rest  = var.enable_encryption_at_rest
  enable_versioning          = var.environment != "dev"
  tags                       = local.aws_tags
  providers = {
    aws = aws
  }
}

module "aws_secrets" {
  source = "./modules/secrets"

  project_name           = var.project_name
  environment            = var.environment
  database_password      = module.aws_database.db_password
  secret_recovery_window = var.secret_recovery_window
  kms_key_rotation       = var.kms_key_rotation_enabled
  tags                   = local.aws_tags
  providers = {
    aws = aws
  }

  depends_on = [module.aws_database]
}

module "aws_monitoring" {
  source = "./modules/monitoring"

  project_name         = var.project_name
  environment          = var.environment
  log_retention_days   = var.log_retention_days
  enable_monitoring    = var.enable_monitoring
  database_id          = module.aws_database.db_instance_id
  cache_id             = module.aws_caching.cluster_id
  asg_name             = module.aws_compute.autoscaling_group_name
  alarm_actions        = []
  tags                 = local.aws_tags
  providers = {
    aws = aws
  }

  depends_on = [module.aws_database, module.aws_caching, module.aws_compute]
}

output "aws_infrastructure_summary" {
  description = "AWS infrastructure summary"
  value = {
    vpc_id           = module.aws_networking.vpc_id
    database_endpoint = module.aws_database.db_endpoint
    cache_endpoint   = module.aws_caching.primary_endpoint
    load_balancer_dns = module.aws_compute.load_balancer_dns
  }
  sensitive = false
}
