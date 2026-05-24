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

variable "database_subnet_group_name" {
  type = string
}

variable "security_group_id" {
  type = string
}

variable "engine_version" {
  type = string
}

variable "instance_class" {
  type = string
}

variable "allocated_storage" {
  type = number
}

variable "backup_retention_days" {
  type = number
}

variable "multi_az" {
  type = bool
}

variable "enable_read_replicas" {
  type = bool
}

variable "enable_encryption_at_rest" {
  type = bool
}

variable "tags" {
  type = map(string)
}

resource "random_password" "database" {
  length  = 16
  special = true
}

resource "aws_db_instance" "main" {
  allocated_storage       = var.allocated_storage
  engine                  = "postgres"
  engine_version          = var.engine_version
  instance_class          = var.instance_class
  identifier              = "${var.project_name}-db"
  username                = "postgres"
  password                = random_password.database.result
  parameter_group_name    = aws_db_parameter_group.main.name
  skip_final_snapshot     = var.environment == "dev"
  final_snapshot_identifier = "${var.project_name}-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
  db_subnet_group_name    = var.database_subnet_group_name
  vpc_security_group_ids          = [var.security_group_id]
  multi_az                        = var.multi_az
  publicly_accessible             = false
  storage_encrypted               = var.enable_encryption_at_rest
  backup_retention_period         = var.backup_retention_days
  backup_window                   = "03:00-04:00"
  maintenance_window              = "mon:04:00-mon:05:00"
  iam_database_authentication_enabled = true
  enabled_cloudwatch_logs_exports = ["postgresql"]
  deletion_protection             = var.environment == "prod"

  tags = merge(var.tags, {
    Name = "${var.project_name}-database"
  })
}

resource "aws_db_parameter_group" "main" {
  name   = "${var.project_name}-postgres-params"
  family = "postgres15"

  parameter {
    name  = "log_statement"
    value = "all"
  }

  parameter {
    name  = "log_duration"
    value = "1"
  }

  parameter {
    name  = "max_connections"
    value = "1000"
  }

  parameter {
    name  = "shared_buffers"
    value = "{DBInstanceClassMemory/32768}"
  }

  tags = var.tags
}

resource "aws_db_instance" "read_replica" {
  count                  = var.enable_read_replicas ? 1 : 0
  identifier             = "${var.project_name}-db-read-replica"
  replicate_source_db    = aws_db_instance.main.identifier
  instance_class         = var.instance_class
  publicly_accessible    = false
  auto_minor_version_upgrade = true
  skip_final_snapshot    = var.environment == "dev"

  tags = merge(var.tags, {
    Name = "${var.project_name}-database-read-replica"
  })
}

resource "aws_db_proxy" "main" {
  name                   = "${var.project_name}-proxy"
  engine_family          = "POSTGRESQL"
  auth {
    auth_scheme = "SECRETS"
    secret_arn  = aws_secretsmanager_secret.database_password.arn
  }
  role_arn       = aws_iam_role.proxy.arn
  vpc_subnet_ids = []
  debug_logging  = false

  depends_on = [aws_secretsmanager_secret_version.database_password]

  tags = merge(var.tags, {
    Name = "${var.project_name}-db-proxy"
  })
}

resource "aws_secretsmanager_secret" "database_password" {
  name                    = "${var.project_name}/db/password"
  recovery_window_in_days = 7
  description             = "PostgreSQL database password"

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "database_password" {
  secret_id = aws_secretsmanager_secret.database_password.id
  secret_string = jsonencode({
    username = aws_db_instance.main.username
    password = aws_db_instance.main.password
    engine   = "postgres"
    host     = aws_db_instance.main.address
    port     = aws_db_instance.main.port
    dbname   = "postgres"
  })
}

resource "aws_iam_role" "proxy" {
  name = "${var.project_name}-db-proxy-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "rds.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "proxy" {
  name = "${var.project_name}-db-proxy-policy"
  role = aws_iam_role.proxy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetResourcePolicy",
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecretVersionIds"
        ]
        Resource = aws_secretsmanager_secret.database_password.arn
      }
    ]
  })
}

output "db_instance_id" {
  value = aws_db_instance.main.id
}

output "db_endpoint" {
  value = aws_db_instance.main.endpoint
}

output "db_address" {
  value = aws_db_instance.main.address
}

output "db_port" {
  value = aws_db_instance.main.port
}

output "db_name" {
  value = "postgres"
}

output "db_password" {
  value     = random_password.database.result
  sensitive = true
}

output "db_proxy_endpoint" {
  value = aws_db_proxy.main.endpoint
}
