# CloudWatch Alarms for Critical SRE Alerting
# Only essential alarms that require immediate attention

# SNS Topic for Critical Alerts
resource "aws_sns_topic" "alerts" {
  name              = "${var.project_name}-critical-alerts"
  display_name      = "Picus Critical Alerts"
  kms_master_key_id = "alias/aws/sns"

  tags = {
    Name        = "${var.project_name}-alerts"
    Environment = var.environment
  }
}

# Email Subscription
resource "aws_sns_topic_subscription" "email_alerts" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = "mail@fatihkoc.net"
}

# ==================== CRITICAL ALARMS ====================

# 1. API High Error Rate (5xx) - Service is failing
resource "aws_cloudwatch_metric_alarm" "api_high_error_rate" {
  alarm_name          = "${var.project_name}-api-high-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "CRITICAL: API returning >10 5xx errors/minute. Service degraded."
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = {
    Name        = "${var.project_name}-api-high-error-rate"
    Severity    = "Critical"
    Environment = var.environment
  }
}

# 2. Unhealthy Targets - ECS tasks are down
resource "aws_cloudwatch_metric_alarm" "unhealthy_targets" {
  alarm_name          = "${var.project_name}-unhealthy-targets"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = 0
  alarm_description   = "CRITICAL: ECS tasks are unhealthy. Zero healthy targets available."
  treat_missing_data  = "notBreaching"

  dimensions = {
    TargetGroup = aws_lb_target_group.ecs.arn_suffix
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = {
    Name        = "${var.project_name}-unhealthy-targets"
    Severity    = "Critical"
    Environment = var.environment
  }
}

# 3. Lambda Errors - DELETE endpoint failing
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${var.project_name}-lambda-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "CRITICAL: Lambda DELETE function has >5 errors/minute."
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = "picus-${var.environment}-delete"
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = {
    Name        = "${var.project_name}-lambda-errors"
    Severity    = "Critical"
    Environment = var.environment
  }
}

# 4. DynamoDB Throttling - Data layer under stress
resource "aws_cloudwatch_metric_alarm" "dynamodb_throttle" {
  alarm_name          = "${var.project_name}-dynamodb-throttle"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "UserErrors"
  namespace           = "AWS/DynamoDB"
  period              = 60
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "CRITICAL: DynamoDB throttling detected. Increase capacity or optimize queries."
  treat_missing_data  = "notBreaching"

  dimensions = {
    TableName = aws_dynamodb_table.picus_data.name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = {
    Name        = "${var.project_name}-dynamodb-throttle"
    Severity    = "Critical"
    Environment = var.environment
  }
}
