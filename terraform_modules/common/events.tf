# ================================================================
# Slack Error Notificator
# ================================================================

resource "aws_cloudwatch_event_bus" "error_notificator" {
  name = "error_notificator"
}

resource "aws_cloudwatch_event_rule" "error_notificator" {
  event_bus_name = aws_cloudwatch_event_bus.error_notificator.name
  state          = "ENABLED"
  event_pattern = jsonencode({
    account = [data.aws_caller_identity.current.account_id]
  })
}

resource "aws_cloudwatch_event_connection" "dummy" {
  authorization_type = "API_KEY"
  name               = "dummy"

  auth_parameters {
    api_key {
      key   = "DUMMY"
      value = "dummy"
    }
  }
}

resource "aws_cloudwatch_event_api_destination" "error_notificator" {
  for_each            = toset(var.slack_incoming_webhooks)
  connection_arn      = aws_cloudwatch_event_connection.dummy.arn
  http_method         = "POST"
  invocation_endpoint = each.value
  name                = sha256(each.value)
}

resource "aws_cloudwatch_event_target" "error_notificator" {
  for_each       = aws_cloudwatch_event_api_destination.error_notificator
  arn            = each.value.arn
  rule           = aws_cloudwatch_event_rule.error_notificator.name
  event_bus_name = aws_cloudwatch_event_bus.error_notificator.name
  role_arn       = aws_iam_role.event_bridge_invoke_api_destination.arn

  input_transformer {
    input_template = "{\"blocks\": <blocks>}"
    input_paths = {
      blocks = "$.detail.blocks"
    }
  }
}

# ================================================================
# Lambda Entry Archiver
# ================================================================

resource "aws_cloudwatch_event_rule" "lambda_entry_archiver" {
  name_prefix         = "lambda_entry_archiver"
  state               = false ? "ENABLED" : "DISABLED"
  schedule_expression = "cron(0/15 * * * ? *)"
}

resource "aws_cloudwatch_event_target" "lambda_entry_archiver" {
  arn  = module.lambda_entry_archiver.function_alias_arn
  rule = aws_cloudwatch_event_rule.lambda_entry_archiver.name
}

# ================================================================
# Lambda Threads Dumper
# ================================================================

resource "aws_cloudwatch_event_rule" "lambda_threads_dumper" {
  name_prefix         = "lambda_threads_dumper_"
  state               = false ? "ENABLED" : "DISABLED"
  schedule_expression = "cron(7/15 * * * ? *)"
}

resource "aws_cloudwatch_event_target" "lambda_threads_dumper" {
  arn  = module.lambda_threads_dumper.function_alias_arn
  rule = aws_cloudwatch_event_rule.lambda_threads_dumper.name
}
