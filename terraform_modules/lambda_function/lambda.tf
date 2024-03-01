module "function" {
  source = "../lambda_function_basic"

  handler_dir_name               = var.handler_dir_name
  system_name                    = var.system_name
  role_arn                       = var.role_arn
  runtime                        = var.runtime
  handler                        = var.handler
  memory_size                    = var.memory_size
  timeout                        = var.timeout
  layers                         = var.layers
  reserved_concurrent_executions = var.reserved_concurrent_executions
  region                         = var.region
  environment_variables          = var.environment_variables
  alias                          = var.alias
}

resource "aws_cloudwatch_log_subscription_filter" "error_log" {
  destination_arn = var.subscription_destination_lambda_arn
  filter_pattern  = "{ $.level = \"ERROR\" }"
  log_group_name  = module.function.log_group_name
  name            = "error-log"
}

resource "aws_cloudwatch_log_subscription_filter" "unexpected_exist" {
  destination_arn = var.subscription_destination_lambda_arn
  filter_pattern  = "?\"Task timed out\" ?\"Runtime exited with error\" ?\"Runtime.ImportModuleError\""
  log_group_name  = module.function.log_group_name
  name            = "unexpected-exist"
}