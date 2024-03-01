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
# Slack Error Notificator
# ================================================================

resource "aws_cloudwatch_event_rule" "lambda_feed_trailer" {
  name_prefix         = "lambda_feed_trailer_"
  state               = true ? "ENABLED" : "DISABLED"
  schedule_expression = "rate(15 minutes)"
}

resource "aws_cloudwatch_event_target" "lambda_feed_trailer" {
  rule = aws_cloudwatch_event_rule.lambda_feed_trailer.name
  arn  = module.lambda_feed_trailer.function_alias_arn
}