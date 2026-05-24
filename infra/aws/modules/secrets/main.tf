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

variable "database_password" {
  type      = string
  sensitive = true
}

variable "secret_recovery_window" {
  type = number
}

variable "kms_key_rotation" {
  type = bool
}

variable "tags" {
  type = map(string)
}

resource "aws_kms_key" "secrets" {
  description             = "KMS key for Secrets Manager"
  deletion_window_in_days = 10
  enable_key_rotation     = var.kms_key_rotation

  tags = var.tags
}

resource "aws_kms_alias" "secrets" {
  name          = "alias/${var.project_name}-secrets"
  target_key_id = aws_kms_key.secrets.key_id
}

resource "aws_secretsmanager_secret" "database_password" {
  name                    = "${var.project_name}/db/password"
  description             = "PostgreSQL database password"
  recovery_window_in_days = var.secret_recovery_window
  kms_key_id              = aws_kms_key.secrets.id

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "database_password" {
  secret_id     = aws_secretsmanager_secret.database_password.id
  secret_string = var.database_password
}

resource "aws_secretsmanager_secret" "api_keys" {
  name                    = "${var.project_name}/api/keys"
  description             = "API keys for external services"
  recovery_window_in_days = var.secret_recovery_window
  kms_key_id              = aws_kms_key.secrets.id

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "api_keys" {
  secret_id = aws_secretsmanager_secret.api_keys.id
  secret_string = jsonencode({
    service_a_key = "placeholder"
    service_b_key = "placeholder"
  })
}

resource "aws_secretsmanager_secret" "encryption_keys" {
  name                    = "${var.project_name}/encryption/keys"
  description             = "Application encryption keys"
  recovery_window_in_days = var.secret_recovery_window
  kms_key_id              = aws_kms_key.secrets.id

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "encryption_keys" {
  secret_id = aws_secretsmanager_secret.encryption_keys.id
  secret_string = jsonencode({
    master_key = "placeholder"
    secondary_key = "placeholder"
  })
}

resource "aws_secretsmanager_secret_rotation" "api_keys" {
  secret_id           = aws_secretsmanager_secret.api_keys.id
  rotation_lambda_arn = aws_lambda_function.rotation.arn

  rotation_rules {
    automatically_after_days = 30
  }
}

resource "aws_lambda_function" "rotation" {
  filename      = "lambda_rotation.zip"
  function_name = "${var.project_name}-secret-rotation"
  role          = aws_iam_role.lambda.arn
  handler       = "index.handler"
  runtime       = "python3.11"

  environment {
    variables = {
      SECRET_NAME = aws_secretsmanager_secret.api_keys.name
    }
  }

  depends_on = [aws_iam_role_policy_attachment.lambda_basic]
}

resource "aws_iam_role" "lambda" {
  name = "${var.project_name}-secret-rotation-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda.name
}

resource "aws_iam_role_policy" "lambda_secrets" {
  name = "${var.project_name}-lambda-secrets-policy"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:DescribeSecret",
          "secretsmanager:GetSecretValue",
          "secretsmanager:PutSecretValue",
          "secretsmanager:UpdateSecretVersionStage"
        ]
        Resource = aws_secretsmanager_secret.api_keys.arn
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = aws_kms_key.secrets.arn
      }
    ]
  })
}

output "kms_key_id" {
  value = aws_kms_key.secrets.id
}

output "database_secret_arn" {
  value     = aws_secretsmanager_secret.database_password.arn
  sensitive = true
}

output "api_keys_secret_arn" {
  value = aws_secretsmanager_secret.api_keys.arn
}

output "encryption_keys_secret_arn" {
  value = aws_secretsmanager_secret.encryption_keys.arn
}
