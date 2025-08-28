# DynamoDB Table: Messages
resource "aws_dynamodb_table" "messages" {
  name           = "${var.project_name}-messages-${var.environment}"
  billing_mode   = var.dynamodb_billing_mode
  hash_key       = "PK"
  range_key      = "SK"


  attribute {
    name = "PK"
    type = "S"
  }

  attribute {
    name = "SK"
    type = "S"
  }

  attribute {
    name = "channel_id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "N"
  }

  # GSI: チャンネルとタイムスタンプでクエリ
  global_secondary_index {
    name            = "ChannelTimeIndex"
    hash_key        = "channel_id"
    range_key       = "timestamp"
    projection_type = "ALL"

  }

  # TTL設定
  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  # Point-in-time recovery
  point_in_time_recovery {
    enabled = var.enable_point_in_time_recovery
  }

  # 暗号化設定
  server_side_encryption {
    enabled = true
  }

  tags = {
    Name        = "${var.project_name}-messages-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
  }
}

# DynamoDB Table: Processed Messages
resource "aws_dynamodb_table" "processed" {
  name           = "${var.project_name}-processed-${var.environment}"
  billing_mode   = "PAY_PER_REQUEST"  # 処理済みテーブルは常にオンデマンド
  hash_key       = "message_id"

  attribute {
    name = "message_id"
    type = "S"
  }

  # TTL設定
  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  # Point-in-time recovery
  point_in_time_recovery {
    enabled = var.enable_point_in_time_recovery
  }

  # 暗号化設定
  server_side_encryption {
    enabled = true
  }

  tags = {
    Name        = "${var.project_name}-processed-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Auto Scaling for Messages Table (Provisioned mode only)
resource "aws_appautoscaling_target" "messages_table_read" {
  count              = var.dynamodb_billing_mode == "PROVISIONED" && var.enable_dynamodb_autoscaling ? 1 : 0
  max_capacity       = var.dynamodb_autoscale_max_read
  min_capacity       = var.dynamodb_autoscale_min_read
  resource_id        = "table/${aws_dynamodb_table.messages.name}"
  scalable_dimension = "dynamodb:table:ReadCapacityUnits"
  service_namespace  = "dynamodb"
}

resource "aws_appautoscaling_policy" "messages_table_read_policy" {
  count              = var.dynamodb_billing_mode == "PROVISIONED" && var.enable_dynamodb_autoscaling ? 1 : 0
  name               = "${var.project_name}-messages-read-autoscaling-${var.environment}"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.messages_table_read[0].resource_id
  scalable_dimension = aws_appautoscaling_target.messages_table_read[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.messages_table_read[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBReadCapacityUtilization"
    }
    target_value = 70.0
  }
}

resource "aws_appautoscaling_target" "messages_table_write" {
  count              = var.dynamodb_billing_mode == "PROVISIONED" && var.enable_dynamodb_autoscaling ? 1 : 0
  max_capacity       = var.dynamodb_autoscale_max_write
  min_capacity       = var.dynamodb_autoscale_min_write
  resource_id        = "table/${aws_dynamodb_table.messages.name}"
  scalable_dimension = "dynamodb:table:WriteCapacityUnits"
  service_namespace  = "dynamodb"
}

resource "aws_appautoscaling_policy" "messages_table_write_policy" {
  count              = var.dynamodb_billing_mode == "PROVISIONED" && var.enable_dynamodb_autoscaling ? 1 : 0
  name               = "${var.project_name}-messages-write-autoscaling-${var.environment}"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.messages_table_write[0].resource_id
  scalable_dimension = aws_appautoscaling_target.messages_table_write[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.messages_table_write[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBWriteCapacityUtilization"
    }
    target_value = 70.0
  }
}