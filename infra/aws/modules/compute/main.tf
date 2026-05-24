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

variable "vpc_subnets" {
  type = list(string)
}

variable "security_group_ids" {
  type = list(string)
}

variable "instance_type" {
  type = string
}

variable "min_size" {
  type = number
}

variable "max_size" {
  type = number
}

variable "desired_capacity" {
  type = number
}

variable "enable_cost_optimization" {
  type = bool
}

variable "spot_instance_pools" {
  type = number
}

variable "tags" {
  type = map(string)
}

data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_launch_template" "app" {
  name_prefix   = "${var.project_name}-lt-"
  image_id      = data.aws_ami.amazon_linux_2.id
  instance_type = var.instance_type

  vpc_security_group_ids = var.security_group_ids

  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    project_name = var.project_name
  }))

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.tags, {
      Name = "${var.project_name}-instance"
    })
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(var.tags, {
      Name = "${var.project_name}-volume"
    })
  }

  monitoring {
    enabled = true
  }
}

resource "aws_autoscaling_group" "main" {
  name              = "${var.project_name}-asg"
  vpc_zone_identifier = var.vpc_subnets
  target_group_arns = [aws_lb_target_group.app.arn]
  health_check_type = "ELB"
  health_check_grace_period = 300
  min_size          = var.min_size
  max_size          = var.max_size
  desired_capacity  = var.desired_capacity
  default_cooldown  = 300

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  dynamic "mixed_instances_policy" {
    for_each = var.enable_cost_optimization ? [1] : []
    content {
      instances_distribution {
        on_demand_base_capacity                  = 1
        on_demand_percentage_above_base_capacity = 50
        spot_instance_pools                      = var.spot_instance_pools
        spot_max_price                           = ""
      }

      launch_template {
        launch_template_specification {
          launch_template_id = aws_launch_template.app.id
          version            = "$Latest"
        }

        override {
          instance_type     = var.instance_type
          weighted_capacity = "1"
        }

        override {
          instance_type     = replace(var.instance_type, ".medium", ".large")
          weighted_capacity = "1"
        }
      }
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-asg-instance"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [aws_lb.main]
}

resource "aws_autoscaling_policy" "scale_up" {
  name                   = "${var.project_name}-scale-up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.main.name
}

resource "aws_autoscaling_policy" "scale_down" {
  name                   = "${var.project_name}-scale-down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.main.name
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${var.project_name}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "70"
  alarm_actions       = [aws_autoscaling_policy.scale_up.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.main.name
  }
}

resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name          = "${var.project_name}-cpu-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "30"
  alarm_actions       = [aws_autoscaling_policy.scale_down.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.main.name
  }
}

resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = var.security_group_ids
  subnets            = var.vpc_subnets

  enable_deletion_protection = var.environment == "prod"

  tags = merge(var.tags, {
    Name = "${var.project_name}-alb"
  })
}

resource "aws_lb_target_group" "app" {
  name        = "${var.project_name}-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "instance"

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    interval            = 30
    path                = "/health"
    matcher             = "200"
  }

  tags = var.tags
}

resource "aws_lb_listener" "app" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

data "aws_vpc" "default" {
  default = true
}

output "load_balancer_dns" {
  value = aws_lb.main.dns_name
}

output "load_balancer_arn" {
  value = aws_lb.main.arn
}

output "autoscaling_group_name" {
  value = aws_autoscaling_group.main.name
}
