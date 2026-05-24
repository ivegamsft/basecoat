output "deployment_region" {
  description = "Primary deployment region"
  value       = var.aws_primary_region
}

output "environment" {
  description = "Environment name"
  value       = var.environment
}

output "aws_vpc_id" {
  description = "VPC ID"
  value       = module.aws_networking.vpc_id
}

output "aws_private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.aws_networking.private_subnet_ids
}

output "aws_public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.aws_networking.public_subnet_ids
}

output "aws_database_endpoint" {
  description = "Database endpoint"
  value       = module.aws_database.db_endpoint
  sensitive   = true
}

output "aws_database_port" {
  description = "Database port"
  value       = module.aws_database.db_port
}

output "aws_database_name" {
  description = "Database name"
  value       = module.aws_database.db_name
}

output "aws_cache_endpoint" {
  description = "Redis cache primary endpoint"
  value       = module.aws_caching.primary_endpoint
}

output "aws_cache_port" {
  description = "Redis cache port"
  value       = module.aws_caching.port
}

output "aws_load_balancer_dns" {
  description = "Load balancer DNS name"
  value       = module.aws_compute.load_balancer_dns
}

output "aws_load_balancer_arn" {
  description = "Load balancer ARN"
  value       = module.aws_compute.load_balancer_arn
}

output "aws_autoscaling_group_name" {
  description = "Auto Scaling Group name"
  value       = module.aws_compute.autoscaling_group_name
}

output "aws_storage_bucket_name" {
  description = "S3 storage bucket name"
  value       = module.aws_storage.bucket_name
}

output "aws_storage_bucket_arn" {
  description = "S3 storage bucket ARN"
  value       = module.aws_storage.bucket_arn
}

output "aws_secrets_manager_database_password_arn" {
  description = "Secrets Manager ARN for database password"
  value       = module.aws_secrets.database_secret_arn
  sensitive   = true
}

output "aws_cloudwatch_log_group_name" {
  description = "CloudWatch log group name"
  value       = module.aws_monitoring.log_group_name
}

output "aws_monitoring_dashboard_url" {
  description = "CloudWatch dashboard URL"
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${var.aws_primary_region}#dashboards:name=${module.aws_monitoring.dashboard_name}"
}

output "network_security_group_ids" {
  description = "Security group IDs for network segmentation"
  value = {
    database    = module.aws_security.database_security_group_id
    application = module.aws_security.application_security_group_id
    cache       = module.aws_security.cache_security_group_id
    alb         = module.aws_security.alb_security_group_id
  }
}

output "deployment_tags" {
  description = "Tags applied to all resources"
  value       = local.common_tags
}

output "terraform_state_location" {
  description = "Terraform state backend location"
  value       = "Terraform Cloud (app.terraform.io)"
}

output "ha_dr_configuration" {
  description = "High Availability and Disaster Recovery configuration"
  value = {
    primary_region    = var.aws_primary_region
    secondary_region  = var.aws_secondary_region
    database_multi_az = var.database_multi_az
    read_replicas     = var.enable_read_replicas
    rto_hours         = var.rto_hours
    rpo_minutes       = var.rpo_minutes
  }
}
