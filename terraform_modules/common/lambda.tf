# ================================================================
# Layer Common
# ================================================================

data "archive_file" "common_layer" {
  type        = "zip"
  output_path = "layer_common.zip"
  source_dir  = "${path.root}/src/layers/common"
}

resource "aws_lambda_layer_version" "common" {
  layer_name = "layer-common"

  filename         = data.archive_file.common_layer.output_path
  source_code_hash = data.archive_file.common_layer.output_base64sha256
}

# ================================================================
# Lambda Error Notificator
# ================================================================

module "error_notificator" {
  source = "../lambda_function_basic"

  handler_dir_name = "error_notificator"
  handler          = "error_notificator.handler"
  memory_size      = 256
  role_arn         = aws_iam_role.lambda_error_notificator.arn
  environment_variables = {
    EVENT_BUS_NAME = aws_cloudwatch_event_bus.error_notificator.name
    SYSTEM_NAME    = var.system_name
  }

  layers = [
    data.aws_ssm_parameter.base_layer_arn.value,
    aws_lambda_layer_version.common.arn
  ]
  system_name = var.system_name
  region      = var.region
}

resource "aws_lambda_permission" "error_notificator" {
  action        = "lambda:InvokeFunction"
  function_name = module.error_notificator.function_arn
  principal     = "logs.amazonaws.com"
}

# ================================================================
# Lambda Entry Archiver
# ================================================================

module "lambda_entry_archiver" {
  source = "../lambda_function"

  handler_dir_name = "entry_archiver"
  handler          = "entry_archiver.handler"
  memory_size      = 256
  role_arn         = aws_iam_role.lambda_entry_archiver.arn

  environment_variables = {
    DYNAMODB_TABLE_NAME = aws_dynamodb_table.entry_archives.name
  }

  layers = [
    data.aws_ssm_parameter.base_layer_arn.value,
    aws_lambda_layer_version.common.arn,
  ]

  system_name                         = var.system_name
  region                              = var.region
  subscription_destination_lambda_arn = module.error_notificator.function_arn
}

resource "aws_lambda_permission" "lambda_entry_archiver" {
  action        = "lambda:InvokeFunction"
  function_name = module.lambda_entry_archiver.function_name
  qualifier     = module.lambda_entry_archiver.function_alias_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.lambda_entry_archiver.arn
}

# ================================================================
# Lambda Entry Archiver
# ================================================================

module "lambda_entry_parser" {
  source = "../lambda_function"

  handler_dir_name = "entry_parser"
  handler          = "entry_parser.handler"
  memory_size      = 128
  timeout          = aws_sqs_queue.inert_archived_entry.visibility_timeout_seconds
  role_arn         = aws_iam_role.lambda_entry_parser.arn

  environment_variables = {
    DDB_TABLE_NAME_ENTRY_ARCHIVES = aws_dynamodb_table.entry_archives.name
    DDB_TABLE_NAME_THREADS        = aws_dynamodb_table.threads.name
  }

  layers = [
    data.aws_ssm_parameter.base_layer_arn.value,
    aws_lambda_layer_version.common.arn,
  ]

  system_name                         = var.system_name
  region                              = var.region
  subscription_destination_lambda_arn = module.error_notificator.function_arn
}

resource "aws_lambda_event_source_mapping" "lambda_entry_parser" {
  event_source_arn = aws_sqs_queue.inert_archived_entry.arn
  function_name    = module.lambda_entry_parser.function_alias_arn
  batch_size       = 1
  enabled          = true

  maximum_batching_window_in_seconds = aws_sqs_queue.inert_archived_entry.visibility_timeout_seconds

  scaling_config {
    maximum_concurrency = 100
  }
}

# ================================================================
# Lambda Thumbnail Downloader
# ================================================================

module "lambda_thumbnail_downloader" {
  source = "../lambda_function"

  handler_dir_name = "thumbnail_downloader"
  handler          = "thumbnail_downloader.handler"
  memory_size      = 128
  timeout          = aws_sqs_queue.insert_thread.visibility_timeout_seconds
  role_arn         = aws_iam_role.lambda_thumbnail_downloader.arn

  reserved_concurrent_executions = 1

  environment_variables = {
    DYNAMODB_TABLE_NAME = aws_dynamodb_table.threads.name
    S3_BUCKET           = aws_s3_bucket.thumbnails.bucket
    S3_PREFIX           = local.s3.prefix.thumbnails
  }

  layers = [
    data.aws_ssm_parameter.base_layer_arn.value,
    aws_lambda_layer_version.common.arn,
  ]

  system_name                         = var.system_name
  region                              = var.region
  subscription_destination_lambda_arn = module.error_notificator.function_arn
}

resource "aws_lambda_event_source_mapping" "lambda_thumbnail_downloader" {
  event_source_arn = aws_sqs_queue.insert_thread.arn
  function_name    = module.lambda_thumbnail_downloader.function_alias_arn
  batch_size       = 1
  enabled          = false

  maximum_batching_window_in_seconds = aws_sqs_queue.insert_thread.visibility_timeout_seconds
}