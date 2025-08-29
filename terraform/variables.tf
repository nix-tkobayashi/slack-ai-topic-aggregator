# General Configuration
variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "slack-ai-aggregator"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-1"
}

# Slack Configuration
variable "slack_target_channel" {
  description = "Target Slack channel ID for AI summaries"
  type        = string
}

# slack_monitor_channels variable removed - Bot auto-discovers channels

# SSM Parameter Configuration
variable "ssm_parameter_prefix" {
  description = "Prefix for SSM parameter names"
  type        = string
  default     = "slack-ai/prod"
}

variable "create_ssm_placeholders" {
  description = "Create placeholder SSM parameters for secrets (values must be updated manually)"
  type        = bool
  default     = false
}

# Lambda Configuration
variable "lambda_memory_size_event" {
  description = "Memory size for event handler Lambda"
  type        = number
  default     = 256
}

variable "lambda_memory_size_monitor" {
  description = "Memory size for channel monitor Lambda"
  type        = number
  default     = 512
}

variable "lambda_memory_size_summary" {
  description = "Memory size for summary generator Lambda"
  type        = number
  default     = 512
}

variable "lambda_timeout_event" {
  description = "Timeout for event handler Lambda (seconds)"
  type        = number
  default     = 10
}

variable "lambda_timeout_monitor" {
  description = "Timeout for channel monitor Lambda (seconds)"
  type        = number
  default     = 30
}

variable "lambda_timeout_summary" {
  description = "Timeout for summary generator Lambda (seconds)"
  type        = number
  default     = 60
}

# EventBridge Schedule Configuration
variable "monitor_schedule" {
  description = "EventBridge schedule for channel monitoring"
  type        = string
  default     = "rate(5 minutes)"
}

variable "monitor_interval_minutes" {
  description = "Monitoring interval in minutes (should match monitor_schedule)"
  type        = number
  default     = 5
}

variable "summary_schedule" {
  description = "EventBridge schedule for summary generation (cron format in UTC)"
  type        = string
  default     = "cron(0 0,9 * * ? *)"  # 9 AM and 6 PM JST (0 AM and 9 AM UTC)
}

# DynamoDB Configuration
variable "dynamodb_billing_mode" {
  description = "DynamoDB billing mode (PROVISIONED or PAY_PER_REQUEST)"
  type        = string
  default     = "PAY_PER_REQUEST"
}

variable "dynamodb_read_capacity" {
  description = "Read capacity units for DynamoDB table (if PROVISIONED mode)"
  type        = number
  default     = 5
}

variable "dynamodb_write_capacity" {
  description = "Write capacity units for DynamoDB table (if PROVISIONED mode)"
  type        = number
  default     = 5
}

variable "enable_dynamodb_autoscaling" {
  description = "Enable auto-scaling for DynamoDB tables"
  type        = bool
  default     = false
}

variable "dynamodb_autoscale_min_read" {
  description = "Minimum read capacity for auto-scaling"
  type        = number
  default     = 5
}

variable "dynamodb_autoscale_max_read" {
  description = "Maximum read capacity for auto-scaling"
  type        = number
  default     = 20
}

variable "dynamodb_autoscale_min_write" {
  description = "Minimum write capacity for auto-scaling"
  type        = number
  default     = 5
}

variable "dynamodb_autoscale_max_write" {
  description = "Maximum write capacity for auto-scaling"
  type        = number
  default     = 20
}

variable "enable_point_in_time_recovery" {
  description = "Enable point-in-time recovery for DynamoDB tables"
  type        = bool
  default     = false
}

# API Gateway Configuration
variable "enable_api_throttling" {
  description = "Enable API Gateway throttling"
  type        = bool
  default     = true
}

variable "api_throttle_rate" {
  description = "API Gateway throttle rate limit (requests per second)"
  type        = number
  default     = 10
}

variable "api_throttle_burst" {
  description = "API Gateway throttle burst limit"
  type        = number
  default     = 20
}

variable "enable_xray_tracing" {
  description = "Enable X-Ray tracing for API Gateway and Lambda"
  type        = bool
  default     = false
}

# Logging Configuration
variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

# Monitoring Configuration
variable "sns_topic_arn" {
  description = "SNS topic ARN for CloudWatch alarms (optional)"
  type        = string
  default     = ""
}

# Feature Flags
variable "delete_after_summary" {
  description = "Delete messages from DynamoDB after summary generation"
  type        = string
  default     = "false"
}

variable "enable_dlq" {
  description = "Enable Dead Letter Queue for EventBridge"
  type        = bool
  default     = false
}

variable "enable_manual_triggers" {
  description = "Enable manual EventBridge triggers"
  type        = bool
  default     = true
}

# Tags
variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}