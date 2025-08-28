# API Gateway REST API
resource "aws_api_gateway_rest_api" "slack_api" {
  name        = "${var.project_name}-api-${var.environment}"
  description = "API Gateway for Slack Event Subscriptions"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

# API Gateway Resource - /slack
resource "aws_api_gateway_resource" "slack" {
  rest_api_id = aws_api_gateway_rest_api.slack_api.id
  parent_id   = aws_api_gateway_rest_api.slack_api.root_resource_id
  path_part   = "slack"
}

# API Gateway Resource - /slack/events
resource "aws_api_gateway_resource" "events" {
  rest_api_id = aws_api_gateway_rest_api.slack_api.id
  parent_id   = aws_api_gateway_resource.slack.id
  path_part   = "events"
}

# API Gateway Method - POST /slack/events
resource "aws_api_gateway_method" "slack_events_post" {
  rest_api_id   = aws_api_gateway_rest_api.slack_api.id
  resource_id   = aws_api_gateway_resource.events.id
  http_method   = "POST"
  authorization = "NONE"
}

# API Gateway Integration with Lambda
resource "aws_api_gateway_integration" "lambda" {
  rest_api_id = aws_api_gateway_rest_api.slack_api.id
  resource_id = aws_api_gateway_resource.events.id
  http_method = aws_api_gateway_method.slack_events_post.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.event_handler.invoke_arn
}

# API Gateway Method Response
resource "aws_api_gateway_method_response" "slack_events_response" {
  rest_api_id = aws_api_gateway_rest_api.slack_api.id
  resource_id = aws_api_gateway_resource.events.id
  http_method = aws_api_gateway_method.slack_events_post.http_method
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }
}

# API Gateway Integration Response
resource "aws_api_gateway_integration_response" "slack_events_response" {
  rest_api_id = aws_api_gateway_rest_api.slack_api.id
  resource_id = aws_api_gateway_resource.events.id
  http_method = aws_api_gateway_method.slack_events_post.http_method
  status_code = aws_api_gateway_method_response.slack_events_response.status_code

  depends_on = [aws_api_gateway_integration.lambda]
}

# API Gateway Deployment
resource "aws_api_gateway_deployment" "slack_api" {
  depends_on = [
    aws_api_gateway_integration.lambda,
    aws_api_gateway_integration_response.slack_events_response
  ]

  rest_api_id = aws_api_gateway_rest_api.slack_api.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.slack.id,
      aws_api_gateway_resource.events.id,
      aws_api_gateway_method.slack_events_post.id,
      aws_api_gateway_integration.lambda.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

# API Gateway Stage
resource "aws_api_gateway_stage" "slack_api" {
  deployment_id = aws_api_gateway_deployment.slack_api.id
  rest_api_id   = aws_api_gateway_rest_api.slack_api.id
  stage_name    = var.environment

  xray_tracing_enabled = var.enable_xray_tracing

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway_logs.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
      error          = "$context.error.message"
    })
  }
}

# CloudWatch Log Group for API Gateway
resource "aws_cloudwatch_log_group" "api_gateway_logs" {
  name              = "/aws/apigateway/${var.project_name}-${var.environment}"
  retention_in_days = var.log_retention_days
}

# API Gateway Account Settings (必要に応じて)
resource "aws_api_gateway_account" "api_gateway_account" {
  cloudwatch_role_arn = aws_iam_role.api_gateway_cloudwatch.arn
}

# IAM Role for API Gateway CloudWatch Logs
resource "aws_iam_role" "api_gateway_cloudwatch" {
  name = "${var.project_name}-api-gateway-cloudwatch-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "api_gateway_cloudwatch" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
  role       = aws_iam_role.api_gateway_cloudwatch.name
}

# API Gateway Usage Plan (optional)
resource "aws_api_gateway_usage_plan" "slack_api" {
  count = var.enable_api_throttling ? 1 : 0

  name        = "${var.project_name}-usage-plan-${var.environment}"
  description = "Usage plan for Slack API"

  api_stages {
    api_id = aws_api_gateway_rest_api.slack_api.id
    stage  = aws_api_gateway_stage.slack_api.stage_name
  }

  throttle_settings {
    rate_limit  = var.api_throttle_rate
    burst_limit = var.api_throttle_burst
  }
}