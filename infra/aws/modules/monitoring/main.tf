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

variable "log_retention_days" {
  type = number
}

variable "enable_monitoring" {
  type = bool
}

variable "database_id" {
  type = string
}

variable "cache_id" {
  type = string
}

variable "asg_name" {
  type = string
}

variable "alarm_actions" {
  type = list(string)
}

variable "tags" {
  type = map(string)
}

resource "aws_cloudwatch_log_group" "application" {
  name              = "/aws/${var.project_name}/application"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "database" {
  name              = "/aws/${var.project_name}/database"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/RDS", "CPUUtilization", { stat = "Average" }],
            [".", "DatabaseConnections", { stat = "Sum" }],
            [".", "ReadLatency", { stat = "Average" }],
            [".", "WriteLatency", { stat = "Average" }]
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "Database Metrics"
          yAxis = {
            left = {
              min = 0
            }
          }
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ElastiCache", "CPUUtilization", { stat = "Average" }],
            [".", "EngineCPUUtilization", { stat = "Average" }],
            [".", "Evictions", { stat = "Sum" }],
            [".", "ReplicationLag", { stat = "Maximum" }]
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "Redis Cache Metrics"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/EC2", "CPUUtilization", { stat = "Average" }],
            ["AWS/ApplicationELB", "TargetResponseTime", { stat = "Average" }],
            [".", "RequestCount", { stat = "Sum" }],
            [".", "HTTPCode_Target_4XX_Count", { stat = "Sum" }],
            [".", "HTTPCode_Target_5XX_Count", { stat = "Sum" }]
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "Application Metrics"
        }
      }
    ]
  })
}

resource "aws_cloudwatch_metric_alarm" "database_cpu" {
  alarm_name          = "${var.project_name}-database-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "Alert when database CPU exceeds 80%"
  alarm_actions       = var.alarm_actions

  dimensions = {
    DBInstanceIdentifier = var.database_id
  }
}

resource "aws_cloudwatch_metric_alarm" "database_connections" {
  alarm_name          = "${var.project_name}-database-connections-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "800"
  alarm_description   = "Alert when database connections exceed 800"
  alarm_actions       = var.alarm_actions

  dimensions = {
    DBInstanceIdentifier = var.database_id
  }
}

resource "aws_cloudwatch_metric_alarm" "cache_evictions" {
  alarm_name          = "${var.project_name}-cache-evictions"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Evictions"
  namespace           = "AWS/ElastiCache"
  period              = "300"
  statistic           = "Average"
  threshold           = "100"
  alarm_description   = "Alert when cache evictions occur"
  alarm_actions       = var.alarm_actions

  dimensions = {
    ReplicationGroupId = var.cache_id
  }
}

resource "aws_cloudwatch_metric_alarm" "alb_target_5xx" {
  alarm_name          = "${var.project_name}-alb-target-5xx"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "Alert on 5XX errors from targets"
  alarm_actions       = var.alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "asg_unhealthy_hosts" {
  alarm_name          = "${var.project_name}-asg-unhealthy-hosts"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "GroupTerminatingInstances"
  namespace           = "AWS/AutoScaling"
  period              = "300"
  statistic           = "Sum"
  threshold           = "1"
  alarm_description   = "Alert when ASG has unhealthy instances"
  alarm_actions       = var.alarm_actions

  dimensions = {
    AutoScalingGroupName = var.asg_name
  }
}

resource "aws_cloudwatch_log_resource_policy" "allow_cloudtrail" {
  policy_name = "${var.project_name}-allow-cloudtrail"

  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "logs:PutLogEvents"
        Resource = "${aws_cloudwatch_log_group.application.arn}:*"
      }
    ]
  })
}

data "aws_region" "current" {}

output "log_group_name" {
  value = aws_cloudwatch_log_group.application.name
}

output "dashboard_name" {
  value = aws_cloudwatch_dashboard.main.dashboard_name
}
