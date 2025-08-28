# Lambda実行ロール
resource "aws_iam_role" "lambda_execution" {
  name = "${var.project_name}-lambda-role-${var.environment}"

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
}

# Lambda基本実行ポリシー
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda_execution.name
}

# DynamoDBアクセスポリシー
resource "aws_iam_role_policy" "lambda_dynamodb" {
  name = "${var.project_name}-lambda-dynamodb-${var.environment}"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem"
        ]
        Resource = [
          aws_dynamodb_table.messages.arn,
          aws_dynamodb_table.processed.arn,
          "${aws_dynamodb_table.messages.arn}/index/*"
        ]
      }
    ]
  })
}

# SSM Parameter Storeアクセスポリシー
resource "aws_iam_role_policy" "lambda_ssm" {
  name = "${var.project_name}-lambda-ssm-${var.environment}"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${var.ssm_parameter_prefix}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "ssm.${var.aws_region}.amazonaws.com"
          }
        }
      }
    ]
  })
}

# Lambda関数: Event Handler (Slack Webhook)
resource "aws_lambda_function" "event_handler" {
  filename         = data.archive_file.lambda_functions.output_path
  function_name    = "${var.project_name}-event-handler-${var.environment}"
  role            = aws_iam_role.lambda_execution.arn
  handler         = "handlers/event.handler"
  source_code_hash = data.archive_file.lambda_functions.output_base64sha256
  runtime         = "nodejs18.x"
  timeout         = 10
  memory_size     = 256

  layers = [aws_lambda_layer_version.dependencies.arn]

  environment {
    variables = {
      MESSAGES_TABLE      = aws_dynamodb_table.messages.name
      PROCESSED_TABLE     = aws_dynamodb_table.processed.name
      SLACK_BOT_TOKEN     = "ssm:${var.ssm_parameter_prefix}/bot-token"
      SLACK_SIGNING_SECRET = "ssm:${var.ssm_parameter_prefix}/signing-secret"
      MONITOR_CHANNELS    = "ssm:${var.ssm_parameter_prefix}/monitor-channels"
      ENVIRONMENT         = var.environment
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic,
    aws_cloudwatch_log_group.lambda_logs["event-handler"]
  ]
}

# Lambda関数: Channel Monitor (定期監視)
resource "aws_lambda_function" "channel_monitor" {
  filename         = data.archive_file.lambda_functions.output_path
  function_name    = "${var.project_name}-channel-monitor-${var.environment}"
  role            = aws_iam_role.lambda_execution.arn
  handler         = "handlers/monitor.handler"
  source_code_hash = data.archive_file.lambda_functions.output_base64sha256
  runtime         = "nodejs18.x"
  timeout         = 30
  memory_size     = 512

  layers = [aws_lambda_layer_version.dependencies.arn]

  reserved_concurrent_executions = 1

  environment {
    variables = {
      MESSAGES_TABLE     = aws_dynamodb_table.messages.name
      PROCESSED_TABLE    = aws_dynamodb_table.processed.name
      SLACK_BOT_TOKEN    = "ssm:${var.ssm_parameter_prefix}/bot-token"
      TARGET_CHANNEL_ID  = "ssm:${var.ssm_parameter_prefix}/target-channel"
      ENVIRONMENT        = var.environment
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic,
    aws_cloudwatch_log_group.lambda_logs["channel-monitor"]
  ]
}

# Lambda関数: Summary Generator (要約生成)
resource "aws_lambda_function" "summary_generator" {
  filename         = data.archive_file.lambda_functions.output_path
  function_name    = "${var.project_name}-summary-generator-${var.environment}"
  role            = aws_iam_role.lambda_execution.arn
  handler         = "handlers/summary.handler"
  source_code_hash = data.archive_file.lambda_functions.output_base64sha256
  runtime         = "nodejs18.x"
  timeout         = 60
  memory_size     = 512

  layers = [aws_lambda_layer_version.dependencies.arn]

  reserved_concurrent_executions = 1

  environment {
    variables = {
      MESSAGES_TABLE       = aws_dynamodb_table.messages.name
      PROCESSED_TABLE      = aws_dynamodb_table.processed.name
      SLACK_BOT_TOKEN      = "ssm:${var.ssm_parameter_prefix}/bot-token"
      OPENAI_API_KEY       = "ssm:${var.ssm_parameter_prefix}/openai-key"
      TARGET_CHANNEL_ID    = "ssm:${var.ssm_parameter_prefix}/target-channel"
      DELETE_AFTER_SUMMARY = var.delete_after_summary
      ENVIRONMENT          = var.environment
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic,
    aws_cloudwatch_log_group.lambda_logs["summary-generator"]
  ]
}

# Lambda Permission for API Gateway
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.event_handler.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.slack_api.execution_arn}/*/*"
}

# Lambda Permission for EventBridge (Monitor)
resource "aws_lambda_permission" "eventbridge_monitor" {
  statement_id  = "AllowEventBridgeInvokeMonitor"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.channel_monitor.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.monitor_schedule.arn
}

# Lambda Permission for EventBridge (Summary)
resource "aws_lambda_permission" "eventbridge_summary" {
  statement_id  = "AllowEventBridgeInvokeSummary"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.summary_generator.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.summary_schedule.arn
}