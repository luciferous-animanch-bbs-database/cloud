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