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
# Layer Repository Feed Archives
# ================================================================

data "archive_file" "layer_repository_feed_archives" {
  type        = "zip"
  output_path = "layer_repository_feed_archives.zip"
  source_dir  = "${path.root}/src/layers/repository_feed_archives"
}

resource "aws_lambda_layer_version" "repository_feed_archives" {
  layer_name = "layer-repository-feed_archives"

  filename         = data.archive_file.layer_repository_feed_archives.output_path
  source_code_hash = data.archive_file.layer_repository_feed_archives.output_base64sha256
}

# ================================================================
# Lambda Entry Archiver
# ================================================================

data "archive_file" "layer_repository_threads" {
  type        = "zip"
  output_path = "layer_repository_threads.zip"
  source_dir  = "${path.root}/src/layers/repository_threads"
}

resource "aws_lambda_layer_version" "repository_threads" {
  layer_name = "layer_repository_threads"

  filename         = data.archive_file.layer_repository_threads.output_path
  source_code_hash = data.archive_file.layer_repository_threads.output_base64sha256
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
# Lambda Feed Trailer
# ================================================================

module "lambda_feed_trailer" {
  source = "../lambda_function"

  handler_dir_name = "feed_trailer"
  handler          = "feed_trailer.handler"
  memory_size      = 128
  role_arn         = aws_iam_role.lambda_feed_trailer.arn
  environment_variables = {
    DYNAMODB_TABLE_NAME = aws_dynamodb_table.database.name
  }

  layers = [
    data.aws_ssm_parameter.base_layer_arn.value,
    aws_lambda_layer_version.common.arn
  ]
  system_name                         = var.system_name
  region                              = var.region
  subscription_destination_lambda_arn = module.error_notificator.function_arn
}

resource "aws_lambda_permission" "lambda_feed_trailer" {
  action        = "lambda:InvokeFunction"
  function_name = module.lambda_feed_trailer.function_name
  qualifier     = module.lambda_feed_trailer.function_alias_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.lambda_feed_trailer.arn
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
    aws_lambda_layer_version.repository_feed_archives.arn
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
  role_arn         = aws_iam_role.lambda_entry_parser.arn

  environment_variables = {
    DDB_TABLE_NAME_ENTRY_ARCHIVES = aws_dynamodb_table.entry_archives.name
    DDB_TABLE_NAME_THREADS        = aws_dynamodb_table.threads.name
  }


  layers = [
    data.aws_ssm_parameter.base_layer_arn.value,
    aws_lambda_layer_version.common.arn,
    aws_lambda_layer_version.repository_feed_archives.arn,
    aws_lambda_layer_version.repository_threads.arn
  ]

  system_name                         = var.system_name
  region                              = var.region
  subscription_destination_lambda_arn = module.error_notificator.function_arn
}
