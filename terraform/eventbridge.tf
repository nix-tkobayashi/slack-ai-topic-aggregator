# EventBridge Rule - Channel Monitor (5分毎)
resource "aws_cloudwatch_event_rule" "monitor_schedule" {
  name                = "${var.project_name}-monitor-schedule-${var.environment}"
  description         = "Trigger channel monitoring every 5 minutes"
  schedule_expression = var.monitor_schedule

  tags = {
    Name        = "${var.project_name}-monitor-schedule-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
  }
}

# EventBridge Target - Channel Monitor
resource "aws_cloudwatch_event_target" "monitor_lambda" {
  rule      = aws_cloudwatch_event_rule.monitor_schedule.name
  target_id = "MonitorLambdaTarget"
  arn       = aws_lambda_function.channel_monitor.arn

  retry_policy {
    maximum_retry_attempts       = 2
    maximum_event_age_in_seconds = 300
  }
}

# EventBridge Rule - Summary Generator (定時実行)
resource "aws_cloudwatch_event_rule" "summary_schedule" {
  name                = "${var.project_name}-summary-schedule-${var.environment}"
  description         = "Trigger summary generation at scheduled times"
  schedule_expression = var.summary_schedule

  tags = {
    Name        = "${var.project_name}-summary-schedule-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
  }
}

# EventBridge Target - Summary Generator
resource "aws_cloudwatch_event_target" "summary_lambda" {
  rule      = aws_cloudwatch_event_rule.summary_schedule.name
  target_id = "SummaryLambdaTarget"
  arn       = aws_lambda_function.summary_generator.arn

  retry_policy {
    maximum_retry_attempts       = 2
    maximum_event_age_in_seconds = 600
  }
}

# Dead Letter Queue for Failed Events (optional)
resource "aws_sqs_queue" "eventbridge_dlq" {
  count = var.enable_dlq ? 1 : 0

  name                       = "${var.project_name}-eventbridge-dlq-${var.environment}"
  message_retention_seconds  = 1209600  # 14 days
  visibility_timeout_seconds = 300

  tags = {
    Name        = "${var.project_name}-eventbridge-dlq-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
  }
}

# EventBridge Rule for Manual Triggers (optional)
resource "aws_cloudwatch_event_rule" "manual_monitor" {
  count = var.enable_manual_triggers ? 1 : 0

  name        = "${var.project_name}-manual-monitor-${var.environment}"
  description = "Manual trigger for channel monitoring"
  state       = "DISABLED"

  event_pattern = jsonencode({
    source = ["aws.manual"]
    detail-type = ["Manual Channel Monitor"]
  })

  tags = {
    Name        = "${var.project_name}-manual-monitor-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_cloudwatch_event_target" "manual_monitor_lambda" {
  count = var.enable_manual_triggers ? 1 : 0

  rule      = aws_cloudwatch_event_rule.manual_monitor[0].name
  target_id = "ManualMonitorLambdaTarget"
  arn       = aws_lambda_function.channel_monitor.arn
}

# EventBridge Rule for Manual Summary Generation
resource "aws_cloudwatch_event_rule" "manual_summary" {
  count = var.enable_manual_triggers ? 1 : 0

  name        = "${var.project_name}-manual-summary-${var.environment}"
  description = "Manual trigger for summary generation"
  state       = "DISABLED"

  event_pattern = jsonencode({
    source = ["aws.manual"]
    detail-type = ["Manual Summary Generation"]
  })

  tags = {
    Name        = "${var.project_name}-manual-summary-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_cloudwatch_event_target" "manual_summary_lambda" {
  count = var.enable_manual_triggers ? 1 : 0

  rule      = aws_cloudwatch_event_rule.manual_summary[0].name
  target_id = "ManualSummaryLambdaTarget"
  arn       = aws_lambda_function.summary_generator.arn
}