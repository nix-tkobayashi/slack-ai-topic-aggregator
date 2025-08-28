# CloudWatch Alarms for Lambda Functions

# Alarm for Event Handler Errors
resource "aws_cloudwatch_metric_alarm" "event_handler_errors" {
  alarm_name          = "${var.project_name}-event-handler-errors-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "This metric monitors Lambda function errors for Event Handler"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.event_handler.function_name
  }

  alarm_actions = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []

  tags = {
    Name        = "${var.project_name}-event-handler-errors-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Alarm for Channel Monitor Errors
resource "aws_cloudwatch_metric_alarm" "channel_monitor_errors" {
  alarm_name          = "${var.project_name}-channel-monitor-errors-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 2
  alarm_description   = "This metric monitors Lambda function errors for Channel Monitor"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.channel_monitor.function_name
  }

  alarm_actions = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []

  tags = {
    Name        = "${var.project_name}-channel-monitor-errors-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Alarm for Summary Generator Errors
resource "aws_cloudwatch_metric_alarm" "summary_generator_errors" {
  alarm_name          = "${var.project_name}-summary-generator-errors-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "This metric monitors Lambda function errors for Summary Generator"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.summary_generator.function_name
  }

  alarm_actions = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []

  tags = {
    Name        = "${var.project_name}-summary-generator-errors-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Alarm for Lambda Throttles
resource "aws_cloudwatch_metric_alarm" "lambda_throttles" {
  alarm_name          = "${var.project_name}-lambda-throttles-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "This metric monitors Lambda throttling"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.event_handler.function_name
  }

  alarm_actions = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []

  tags = {
    Name        = "${var.project_name}-lambda-throttles-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Alarm for Lambda Duration
resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  alarm_name          = "${var.project_name}-lambda-duration-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Average"
  threshold           = 30000  # 30 seconds
  alarm_description   = "This metric monitors Lambda execution duration"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.summary_generator.function_name
  }

  alarm_actions = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []

  tags = {
    Name        = "${var.project_name}-lambda-duration-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
  }
}

# DynamoDB Alarms

# Alarm for DynamoDB Throttled Requests
resource "aws_cloudwatch_metric_alarm" "dynamodb_throttles" {
  count = var.dynamodb_billing_mode == "PROVISIONED" ? 1 : 0

  alarm_name          = "${var.project_name}-dynamodb-throttles-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "ConsumedReadCapacityUnits"
  namespace           = "AWS/DynamoDB"
  period              = 300
  statistic           = "Sum"
  threshold           = var.dynamodb_read_capacity * 300 * 0.8  # 80% of capacity
  alarm_description   = "This metric monitors DynamoDB read capacity"
  treat_missing_data  = "notBreaching"

  dimensions = {
    TableName = aws_dynamodb_table.messages.name
  }

  alarm_actions = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []

  tags = {
    Name        = "${var.project_name}-dynamodb-throttles-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
  }
}

# API Gateway 4XX Errors
resource "aws_cloudwatch_metric_alarm" "api_gateway_4xx" {
  alarm_name          = "${var.project_name}-api-4xx-errors-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "4XXError"
  namespace           = "AWS/ApiGateway"
  period              = 300
  statistic           = "Sum"
  threshold           = 50
  alarm_description   = "This metric monitors API Gateway 4XX errors"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ApiName = aws_api_gateway_rest_api.slack_api.name
    Stage   = aws_api_gateway_stage.slack_api.stage_name
  }

  alarm_actions = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []

  tags = {
    Name        = "${var.project_name}-api-4xx-errors-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
  }
}

# API Gateway 5XX Errors
resource "aws_cloudwatch_metric_alarm" "api_gateway_5xx" {
  alarm_name          = "${var.project_name}-api-5xx-errors-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "5XXError"
  namespace           = "AWS/ApiGateway"
  period              = 60
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "This metric monitors API Gateway 5XX errors"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ApiName = aws_api_gateway_rest_api.slack_api.name
    Stage   = aws_api_gateway_stage.slack_api.stage_name
  }

  alarm_actions = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []

  tags = {
    Name        = "${var.project_name}-api-5xx-errors-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
  }
}