data "archive_file" "package" {
  type        = "zip"
  output_path = "function_${var.handler_dir_name}.zip"
  source_dir  = "${path.root}/src/handlers/${var.handler_dir_name}"
}

resource "aws_lambda_function" "function" {
  function_name                  = replace("${var.system_name}-${var.handler_dir_name}", "_", "-")
  role                           = var.role_arn
  runtime                        = var.runtime
  architectures                  = ["arm64"]
  handler                        = var.handler
  memory_size                    = var.memory_size
  timeout                        = var.timeout
  filename                       = data.archive_file.package.output_path
  source_code_hash               = data.archive_file.package.output_base64sha256
  reserved_concurrent_executions = var.reserved_concurrent_executions
  publish                        = true

  layers = concat(var.layers, [
    # Powertools for AWS Lambda (Python) [arm64] with extra dependencies version 2.34.2
    "arn:aws:lambda:${var.region}:017000801446:layer:AWSLambdaPowertoolsPythonV2-Arm64:65"
  ])

  environment {
    variables = var.environment_variables
  }
}

resource "aws_lambda_alias" "function" {
  function_name    = aws_lambda_function.function.function_name
  function_version = aws_lambda_function.function.version
  name             = var.alias
}
