variable "project_name" {
  description = "Project name"
  type        = string
  default     = "basecoat-portal"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "region" {
  description = "Primary AWS region"
  type        = string
  default     = "us-east-1"
}

variable "aws_primary_region" {
  description = "AWS primary region"
  type        = string
  default     = "us-east-1"
}

variable "aws_secondary_region" {
  description = "AWS secondary region for DR"
  type        = string
  default     = "us-west-2"
}

variable "aws_role_arn" {
  description = "AWS IAM role ARN for provider assumption"
  type        = string
  default     = ""
}

variable "azure_resource_group" {
  description = "Azure Resource Group name"
  type        = string
}

variable "azure_location_primary" {
  description = "Azure primary region"
  type        = string
  default     = "East US"
}

variable "azure_location_secondary" {
  description = "Azure secondary region for DR"
  type        = string
  default     = "West US"
}

variable "gcp_project_id" {
  description = "GCP project ID"
  type        = string
}

variable "gcp_primary_region" {
  description = "GCP primary region"
  type        = string
  default     = "us-central1"
}

variable "gcp_secondary_region" {
  description = "GCP secondary region for DR"
  type        = string
  default     = "us-east1"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "private_subnets_cidr" {
  description = "Private subnets CIDR blocks"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "public_subnets_cidr" {
  description = "Public subnets CIDR blocks"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "database_engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "15.3"
}

variable "database_instance_class" {
  description = "Database instance class"
  type        = string
  default     = "db.t3.small"
}

variable "database_allocated_storage" {
  description = "Database allocated storage in GB"
  type        = number
  default     = 100
}

variable "database_backup_retention_days" {
  description = "Database backup retention period in days"
  type        = number
  default     = 30
}

variable "database_multi_az" {
  description = "Enable multi-AZ deployment"
  type        = bool
  default     = true
}

variable "enable_read_replicas" {
  description = "Enable read replicas for database"
  type        = bool
  default     = true
}

variable "compute_instance_type" {
  description = "Compute instance type"
  type        = string
  default     = "t3.medium"
}

variable "compute_min_size" {
  description = "Minimum compute instances"
  type        = number
  default     = 2
}

variable "compute_max_size" {
  description = "Maximum compute instances"
  type        = number
  default     = 10
}

variable "compute_desired_capacity" {
  description = "Desired compute instances"
  type        = number
  default     = 3
}

variable "cache_instance_type" {
  description = "Redis cache instance type"
  type        = string
  default     = "cache.t3.small"
}

variable "cache_num_cache_nodes" {
  description = "Number of cache nodes"
  type        = number
  default     = 2
}

variable "cache_automatic_failover_enabled" {
  description = "Enable automatic failover for cache"
  type        = bool
  default     = true
}

variable "cache_automatic_failover_disabled" {
  description = "Disable automatic failover for cache"
  type        = bool
  default     = false
}

variable "enable_waf" {
  description = "Enable Web Application Firewall"
  type        = bool
  default     = true
}

variable "enable_monitoring" {
  description = "Enable CloudWatch monitoring"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

variable "enable_encryption_at_rest" {
  description = "Enable encryption at rest for all resources"
  type        = bool
  default     = true
}

variable "kms_key_rotation_enabled" {
  description = "Enable KMS key rotation"
  type        = bool
  default     = true
}

variable "secret_recovery_window" {
  description = "Recovery window for deleted secrets (days)"
  type        = number
  default     = 30
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    ManagedBy = "Terraform"
    Project   = "Basecoat-Portal"
  }
}

variable "enable_multi_region_deployment" {
  description = "Enable multi-region deployment with failover"
  type        = bool
  default     = true
}

variable "rto_hours" {
  description = "Recovery Time Objective in hours"
  type        = number
  default     = 4
}

variable "rpo_minutes" {
  description = "Recovery Point Objective in minutes"
  type        = number
  default     = 60
}

variable "enable_cost_optimization" {
  description = "Enable cost optimization strategies"
  type        = bool
  default     = true
}

variable "spot_instance_pools" {
  description = "Number of spot instance pools for interruption tolerance"
  type        = number
  default     = 2
}

variable "reserved_instance_utilization" {
  description = "Reserved instance utilization percentage"
  type        = number
  default     = 70
}
