terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Lambda関数用のZIPアーカイブを作成
# srcディレクトリ全体をパッケージング
data "archive_file" "lambda_functions" {
  type        = "zip"
  output_path = "${path.module}/lambda_function.zip"
  source_dir  = "${path.module}/../src"
  
  excludes = [
    "node_modules/aws-sdk",
    ".DS_Store",
    "*.md",
    "*.test.js",
    "*.spec.js"
  ]
}

# Lambda Layer for dependencies
resource "aws_lambda_layer_version" "dependencies" {
  filename            = "${path.module}/layer.zip"
  layer_name          = "${var.project_name}-dependencies-${var.environment}"
  compatible_runtimes = ["nodejs20.x"]
  description         = "Dependencies for Slack AI Aggregator"
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "lambda_logs" {
  for_each = toset(["channel-monitor", "summary-generator"])
  
  name              = "/aws/lambda/${var.project_name}-${each.key}-${var.environment}"
  retention_in_days = var.log_retention_days
}

# S3 bucket for Lambda artifacts (optional)
resource "aws_s3_bucket" "lambda_artifacts" {
  bucket = "${var.project_name}-artifacts-${var.environment}-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_versioning" "lambda_artifacts" {
  bucket = aws_s3_bucket.lambda_artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "lambda_artifacts" {
  bucket = aws_s3_bucket.lambda_artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

data "aws_caller_identity" "current" {}