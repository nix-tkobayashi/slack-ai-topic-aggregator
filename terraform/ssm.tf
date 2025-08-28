# SSM Parameters for Slack and OpenAI credentials
# Note: These should be created manually with secure values before running Terraform

# Data sources to read existing parameters
data "aws_ssm_parameter" "slack_bot_token" {
  name = "/${var.ssm_parameter_prefix}/bot-token"
}

data "aws_ssm_parameter" "slack_signing_secret" {
  name = "/${var.ssm_parameter_prefix}/signing-secret"
}

data "aws_ssm_parameter" "openai_api_key" {
  name = "/${var.ssm_parameter_prefix}/openai-key"
}

# Configuration parameters that can be managed by Terraform
resource "aws_ssm_parameter" "target_channel" {
  name        = "/${var.ssm_parameter_prefix}/target-channel"
  description = "Target Slack channel ID for AI summaries"
  type        = "String"
  value       = var.slack_target_channel
  tier        = "Standard"

  tags = {
    Name        = "${var.project_name}-target-channel-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Monitor channels are auto-discovered - Bot monitors all channels it's invited to

# Optional: Create placeholders for secure parameters (values must be updated manually)
resource "aws_ssm_parameter" "slack_bot_token_placeholder" {
  count = var.create_ssm_placeholders ? 1 : 0

  name        = "/${var.ssm_parameter_prefix}/bot-token"
  description = "Slack Bot User OAuth Token (xoxb-...)"
  type        = "SecureString"
  value       = "PLACEHOLDER_UPDATE_MANUALLY"
  tier        = "Standard"

  lifecycle {
    ignore_changes = [value]
  }

  tags = {
    Name        = "${var.project_name}-bot-token-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
    Note        = "Update value manually via AWS Console or CLI"
  }
}

resource "aws_ssm_parameter" "slack_signing_secret_placeholder" {
  count = var.create_ssm_placeholders ? 1 : 0

  name        = "/${var.ssm_parameter_prefix}/signing-secret"
  description = "Slack Signing Secret for request verification"
  type        = "SecureString"
  value       = "PLACEHOLDER_UPDATE_MANUALLY"
  tier        = "Standard"

  lifecycle {
    ignore_changes = [value]
  }

  tags = {
    Name        = "${var.project_name}-signing-secret-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
    Note        = "Update value manually via AWS Console or CLI"
  }
}

resource "aws_ssm_parameter" "openai_api_key_placeholder" {
  count = var.create_ssm_placeholders ? 1 : 0

  name        = "/${var.ssm_parameter_prefix}/openai-key"
  description = "OpenAI API Key (sk-...)"
  type        = "SecureString"
  value       = "PLACEHOLDER_UPDATE_MANUALLY"
  tier        = "Standard"

  lifecycle {
    ignore_changes = [value]
  }

  tags = {
    Name        = "${var.project_name}-openai-key-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
    Note        = "Update value manually via AWS Console or CLI"
  }
}