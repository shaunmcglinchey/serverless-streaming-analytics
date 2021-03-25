##################################################################################
# VARIABLES
##################################################################################

variable "environment_tag" {}
variable "app_autoscaling_enabled" {}
variable "app_parallelism" {}
variable "app_log_group" {}
variable "app_log_level" {}
variable "app_log_stream" {}
variable "app_name" {}
variable "app_runtime_environment" {}
variable "app_sink_bucket" {}
variable "app_source" {}
variable "kinesis_input_stream" {}
variable "lambda" {}
variable "lambda_handler" {}
variable "lambda_log_group" {}

##################################################################################
# PROVIDERS
##################################################################################

provider "aws" {}

terraform {
  required_providers {
    snowflake = {
      source  = "chanzuckerberg/snowflake"
      version = "0.22.0"
    }
  }
}

##################################################################################
# DATA
##################################################################################

data "aws_iam_policy_document" "kinesis_app_policy_doc" {
  statement {
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:DeleteObjectVersion"
    ]

    resources = [
      "arn:aws:s3:::${var.app_name}",
      "arn:aws:s3:::${var.app_name}/*",
      "arn:aws:s3:::${var.app_sink_bucket}",
      "arn:aws:s3:::${var.app_sink_bucket}/*"
    ]
  }
  statement {
    actions = ["kinesis:*"]

    resources = [aws_kinesis_stream.aks-input.arn]
  }
}

data "aws_iam_policy_document" "lambda_logging_policy_doc" {
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]

    resources = [
      "arn:aws:logs:*:*:*"
    ]
  }
}

##################################################################################
# RESOURCES
##################################################################################

resource "aws_kinesis_stream" "aks-input" {
  name             = var.kinesis_input_stream
  shard_count      = 1
  tags = {
    Environment = var.environment_tag
  }
}

resource "aws_s3_bucket" "sink" {
  bucket = var.app_sink_bucket
  force_destroy = true
}

resource "aws_s3_bucket" "asb" {
  bucket = var.app_name
  force_destroy = true
}

resource "aws_s3_bucket_object" "flink_app" {
  bucket = aws_s3_bucket.asb.bucket
  key    = var.app_name
  source = var.app_source
}

resource "aws_cloudwatch_log_group" "flink_app_log_group" {
  name = var.app_log_group
}

resource "aws_cloudwatch_log_stream" "flink_app_log_stream" {
  name           = var.app_log_stream
  log_group_name = aws_cloudwatch_log_group.flink_app_log_group.name
}

resource "aws_kinesisanalyticsv2_application" "akaf" {
  name                   = var.app_name
  runtime_environment    = var.app_runtime_environment
  service_execution_role = aws_iam_role.ksr.arn

  cloudwatch_logging_options {
    log_stream_arn = aws_cloudwatch_log_stream.flink_app_log_stream.arn
  }

  application_configuration {
    application_code_configuration {
      code_content {
        s3_content_location {
          bucket_arn = aws_s3_bucket.asb.arn
          file_key   = aws_s3_bucket_object.flink_app.key
        }
      }
      code_content_type = "ZIPFILE"
    }
    flink_application_configuration {
      checkpoint_configuration {
        configuration_type = "DEFAULT"
      }

      monitoring_configuration {
        configuration_type = "DEFAULT"
        log_level          = var.app_log_level
      }

      parallelism_configuration {
        auto_scaling_enabled = var.app_autoscaling_enabled
        configuration_type   = "DEFAULT"
        parallelism          = var.app_parallelism
      }
    } 
  }
}

resource "aws_iam_role" "ksr" {
  name = "ksr"
  assume_role_policy = jsonencode({
    Version: "2012-10-17",
    Statement: [
      {
        Action: "sts:AssumeRole",
        Principal: {
          Service: "kinesisanalytics.amazonaws.com"
        },
        Effect: "Allow"
      }
    ]
  })
}

resource "aws_iam_role_policy" "ksp" {
  name = "${var.app_name}-policy"
  role = aws_iam_role.ksr.id
  policy = data.aws_iam_policy_document.kinesis_app_policy_doc.json
}

resource "aws_iam_role" "app_lambda" {
  name = "app_lambda"
  assume_role_policy = jsonencode({
    Version: "2012-10-17",
    Statement: [
      {
        Action: "sts:AssumeRole",
        Principal: {
          Service: "lambda.amazonaws.com"
        },
        Effect: "Allow"
      }
    ]
  })
}

resource "aws_lambda_function" "app_lambda" {
    filename = "${var.lambda}.zip"
    function_name = var.lambda
    role = aws_iam_role.app_lambda.arn
    handler = var.lambda_handler
    runtime = "python3.8"
    timeout = 10
    source_code_hash = filebase64sha256("${var.lambda}.zip")
    depends_on = [
      aws_iam_role_policy_attachment.lambda_logs,
      aws_cloudwatch_log_group.lambda_log_group
    ]
}

resource "aws_lambda_permission" "allow_bucket" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.app_lambda.arn
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.sink.arn
}

resource "aws_s3_bucket_notification" "notification" {
  bucket = aws_s3_bucket.sink.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.app_lambda.arn
    events              = ["s3:ObjectCreated:CompleteMultipartUpload"]
  }

  depends_on = [aws_lambda_permission.allow_bucket]
}

resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = var.lambda_log_group
  retention_in_days = 14
}

resource "aws_iam_policy" "lambda_logging" {
  name        = "${var.lambda}_logging_policy"
  path        = "/"
  policy = data.aws_iam_policy_document.lambda_logging_policy_doc.json
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.app_lambda.name
  policy_arn = aws_iam_policy.lambda_logging.arn
}