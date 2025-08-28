# API Gateway Outputs
output "api_gateway_url" {
  description = "URL for Slack Event Subscriptions webhook"
  value       = "${aws_api_gateway_stage.slack_api.invoke_url}/slack/events"
}

output "api_gateway_id" {
  description = "API Gateway ID"
  value       = aws_api_gateway_rest_api.slack_api.id
}

output "api_gateway_stage" {
  description = "API Gateway stage name"
  value       = aws_api_gateway_stage.slack_api.stage_name
}

# Lambda Function Outputs
output "lambda_event_handler_arn" {
  description = "ARN of the event handler Lambda function"
  value       = aws_lambda_function.event_handler.arn
}

output "lambda_event_handler_name" {
  description = "Name of the event handler Lambda function"
  value       = aws_lambda_function.event_handler.function_name
}

output "lambda_channel_monitor_arn" {
  description = "ARN of the channel monitor Lambda function"
  value       = aws_lambda_function.channel_monitor.arn
}

output "lambda_channel_monitor_name" {
  description = "Name of the channel monitor Lambda function"
  value       = aws_lambda_function.channel_monitor.function_name
}

output "lambda_summary_generator_arn" {
  description = "ARN of the summary generator Lambda function"
  value       = aws_lambda_function.summary_generator.arn
}

output "lambda_summary_generator_name" {
  description = "Name of the summary generator Lambda function"
  value       = aws_lambda_function.summary_generator.function_name
}

# DynamoDB Table Outputs
output "dynamodb_messages_table_name" {
  description = "Name of the messages DynamoDB table"
  value       = aws_dynamodb_table.messages.name
}

output "dynamodb_messages_table_arn" {
  description = "ARN of the messages DynamoDB table"
  value       = aws_dynamodb_table.messages.arn
}

output "dynamodb_processed_table_name" {
  description = "Name of the processed messages DynamoDB table"
  value       = aws_dynamodb_table.processed.name
}

output "dynamodb_processed_table_arn" {
  description = "ARN of the processed messages DynamoDB table"
  value       = aws_dynamodb_table.processed.arn
}

# EventBridge Schedule Outputs
output "eventbridge_monitor_rule_arn" {
  description = "ARN of the channel monitor EventBridge rule"
  value       = aws_cloudwatch_event_rule.monitor_schedule.arn
}

output "eventbridge_summary_rule_arn" {
  description = "ARN of the summary generator EventBridge rule"
  value       = aws_cloudwatch_event_rule.summary_schedule.arn
}

# IAM Role Outputs
output "lambda_execution_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.lambda_execution.arn
}

output "lambda_execution_role_name" {
  description = "Name of the Lambda execution role"
  value       = aws_iam_role.lambda_execution.name
}

# CloudWatch Log Group Outputs
output "cloudwatch_log_groups" {
  description = "CloudWatch log group names for Lambda functions"
  value = {
    event_handler      = aws_cloudwatch_log_group.lambda_logs["event-handler"].name
    channel_monitor    = aws_cloudwatch_log_group.lambda_logs["channel-monitor"].name
    summary_generator  = aws_cloudwatch_log_group.lambda_logs["summary-generator"].name
    api_gateway        = aws_cloudwatch_log_group.api_gateway_logs.name
  }
}

# S3 Bucket Output
output "s3_artifacts_bucket" {
  description = "S3 bucket name for Lambda artifacts"
  value       = aws_s3_bucket.lambda_artifacts.id
}

# SSM Parameter Outputs
output "ssm_parameters" {
  description = "SSM parameter names for configuration"
  value = {
    target_channel   = aws_ssm_parameter.target_channel.name
    bot_token        = "/${var.ssm_parameter_prefix}/bot-token"
    signing_secret   = "/${var.ssm_parameter_prefix}/signing-secret"
    openai_key       = "/${var.ssm_parameter_prefix}/openai-key"
  }
  sensitive = true
}

# Monitoring Outputs
output "cloudwatch_alarms" {
  description = "CloudWatch alarm names"
  value = {
    event_handler_errors      = aws_cloudwatch_metric_alarm.event_handler_errors.alarm_name
    channel_monitor_errors    = aws_cloudwatch_metric_alarm.channel_monitor_errors.alarm_name
    summary_generator_errors  = aws_cloudwatch_metric_alarm.summary_generator_errors.alarm_name
    lambda_throttles          = aws_cloudwatch_metric_alarm.lambda_throttles.alarm_name
    lambda_duration           = aws_cloudwatch_metric_alarm.lambda_duration.alarm_name
    api_gateway_4xx          = aws_cloudwatch_metric_alarm.api_gateway_4xx.alarm_name
    api_gateway_5xx          = aws_cloudwatch_metric_alarm.api_gateway_5xx.alarm_name
  }
}

# Manual Trigger Information (if enabled)
output "manual_triggers" {
  description = "Manual EventBridge trigger information"
  value = var.enable_manual_triggers ? {
    monitor_rule = aws_cloudwatch_event_rule.manual_monitor[0].name
    summary_rule = aws_cloudwatch_event_rule.manual_summary[0].name
    example_command = "aws events put-events --entries 'Source=aws.manual,DetailType=Manual Channel Monitor,Detail=\"{}\"'"
  } : null
}

# Deployment Information
output "deployment_info" {
  description = "Deployment configuration summary"
  value = {
    project_name     = var.project_name
    environment      = var.environment
    region           = var.aws_region
    monitor_schedule = var.monitor_schedule
    summary_schedule = var.summary_schedule
    api_endpoint     = "${aws_api_gateway_stage.slack_api.invoke_url}/slack/events"
  }
}