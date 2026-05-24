terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "subnet_group_name" {
  type = string
}

variable "security_group_id" {
  type = string
}

variable "cache_node_type" {
  type = string
}

variable "num_cache_nodes" {
  type = number
}

variable "automatic_failover_enabled" {
  type = bool
}

variable "enable_encryption_at_rest" {
  type = bool
}

variable "tags" {
  type = map(string)
}

resource "aws_elasticache_replication_group" "main" {
  replication_group_id       = "${var.project_name}-redis"
  description                = "Redis cluster for ${var.project_name}"
  engine                     = "redis"
  engine_version             = "7.0"
  node_type                  = var.cache_node_type
  num_cache_clusters         = var.num_cache_nodes
  parameter_group_name       = aws_elasticache_parameter_group.main.name
  port                       = 6379
  subnet_group_name          = var.subnet_group_name
  security_group_ids         = [var.security_group_id]
  automatic_failover_enabled = var.automatic_failover_enabled
  multi_az_enabled           = var.automatic_failover_enabled
  at_rest_encryption_enabled = var.enable_encryption_at_rest
  transit_encryption_enabled = var.enable_encryption_at_rest
  transit_encryption_mode    = var.enable_encryption_at_rest ? "preferred" : null
  auth_token                 = var.enable_encryption_at_rest ? random_password.auth_token[0].result : null
  auto_minor_version_upgrade = true
  notification_topic_arn     = aws_sns_topic.elasticache_notifications.arn
  snapshot_retention_limit   = 5
  snapshot_window            = "03:00-05:00"
  maintenance_window         = "sun:04:00-sun:06:00"
  apply_immediately          = var.environment != "prod"

  log_delivery_configuration {
    destination      = aws_cloudwatch_log_group.elasticache_slow_log.name
    destination_type = "cloudwatch-logs"
    log_format       = "json"
    log_type         = "slow-log"
  }

  log_delivery_configuration {
    destination      = aws_cloudwatch_log_group.elasticache_engine_log.name
    destination_type = "cloudwatch-logs"
    log_format       = "json"
    log_type         = "engine-log"
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-redis"
  })
}

resource "aws_elasticache_parameter_group" "main" {
  name   = "${var.project_name}-pg"
  family = "redis7"

  parameter {
    name  = "maxmemory-policy"
    value = "allkeys-lru"
  }

  parameter {
    name  = "timeout"
    value = "300"
  }

  tags = var.tags
}

resource "random_password" "auth_token" {
  count   = var.enable_encryption_at_rest ? 1 : 0
  length  = 32
  special = true
}

resource "aws_cloudwatch_log_group" "elasticache_slow_log" {
  name              = "/aws/elasticache/${var.project_name}/slow-log"
  retention_in_days = 7

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "elasticache_engine_log" {
  name              = "/aws/elasticache/${var.project_name}/engine-log"
  retention_in_days = 7

  tags = var.tags
}

resource "aws_sns_topic" "elasticache_notifications" {
  name = "${var.project_name}-elasticache-notifications"

  tags = var.tags
}

output "primary_endpoint" {
  value = aws_elasticache_replication_group.main.primary_endpoint_address
}

output "reader_endpoint" {
  value = aws_elasticache_replication_group.main.reader_endpoint_address
}

output "port" {
  value = aws_elasticache_replication_group.main.port
}

output "cluster_id" {
  value = aws_elasticache_replication_group.main.id
}

output "auth_token" {
  value     = var.enable_encryption_at_rest ? random_password.auth_token[0].result : ""
  sensitive = true
}
