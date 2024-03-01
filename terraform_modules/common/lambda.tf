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