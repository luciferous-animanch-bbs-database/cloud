# ================================================================
# Assume Role Policy Document
# ================================================================

data "aws_iam_policy_document" "assume_role_policy_event_bridge" {
  policy_id = "assume_role_policy_event_bridge"
  statement {
    sid     = "AssumeRolePolicyEventBridge"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["events.amazonaws.com"]
      type        = "Service"
    }
  }
}

data "aws_iam_policy_document" "assume_role_policy_lambda" {
  policy_id = "assume_role_policy_lambda"
  statement {
    sid     = "AssumeRolePolicyLambda"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["lambda.amazonaws.com"]
      type        = "Service"
    }
  }
}

data "aws_iam_policy_document" "assume_role_policy_pipes" {
  policy_id = "assume_role_policy_pipes"
  statement {
    sid     = "AssumeRolePolicyPipes"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["pipes.amazonaws.com"]
      type        = "Service"
    }
  }
}

# ================================================================
# Policy EventBridge Invoke API Destination
# ================================================================

data "aws_iam_policy_document" "policy_event_bridge_invoke_api_destination" {
  policy_id = "policy_event_bridge_invoke_api_destination"
  statement {
    sid       = "AllowEventBridgeInvokeApiDestination"
    effect    = "Allow"
    actions   = ["events:InvokeApiDestination"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "event_bridge_invoke_api_destination" {
  policy = data.aws_iam_policy_document.policy_event_bridge_invoke_api_destination.json
}

# ================================================================
# Policy EventBridge Put Events
# ================================================================

data "aws_iam_policy_document" "policy_event_bridge_put_events" {
  policy_id = "policy_event_bridge_put_events"
  statement {
    sid       = "AllowEventBridgePutEvents"
    effect    = "Allow"
    actions   = ["events:PutEvents"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "event_bridge_put_events" {
  policy = data.aws_iam_policy_document.policy_event_bridge_put_events.json
}

# ================================================================
# Role EventBridge Invoke API Destination
# ================================================================

resource "aws_iam_role" "event_bridge_invoke_api_destination" {
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy_event_bridge.json
}

resource "aws_iam_role_policy_attachment" "event_bridge_api_destination" {
  for_each = {
    a = aws_iam_policy.event_bridge_invoke_api_destination.arn
  }
  policy_arn = each.value
  role       = aws_iam_role.event_bridge_invoke_api_destination.name
}

# ================================================================
# Role Pipe Insert Archived Entry
# ================================================================

resource "aws_iam_role" "pipes_insert_archived_entry" {
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy_pipes.json
}

resource "aws_iam_role_policy_attachment" "pipes_insert_archived_entry" {
  for_each = {
    a = "arn:aws:iam::aws:policy/service-role/AWSLambdaDynamoDBExecutionRole"
    b = "arn:aws:iam::aws:policy/AmazonSQSFullAccess"
  }
  policy_arn = each.value
  role       = aws_iam_role.pipes_insert_archived_entry.name
}

# ================================================================
# Role Lambda Error Notificator
# ================================================================

resource "aws_iam_role" "lambda_error_notificator" {
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy_lambda.json
}

resource "aws_iam_role_policy_attachment" "lambda_error_notificator" {
  for_each = {
    a = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
    b = aws_iam_policy.event_bridge_put_events.arn
  }
  policy_arn = each.value
  role       = aws_iam_role.lambda_error_notificator.name
}

# ================================================================
# Role Lambda Feed Trailer
# ================================================================

resource "aws_iam_role" "lambda_feed_trailer" {
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy_lambda.json
}

resource "aws_iam_role_policy_attachment" "lambda_feed_trailer" {
  for_each = {
    a = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
    b = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
  }
  policy_arn = each.value
  role       = aws_iam_role.lambda_feed_trailer.name
}

# ================================================================
# Role Lambda Entry Archiver
# ================================================================

resource "aws_iam_role" "lambda_entry_archiver" {
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy_lambda.json
}

resource "aws_iam_role_policy_attachment" "lambda_entry_archiver" {
  for_each = {
    a = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
    b = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
  }
  policy_arn = each.value
  role       = aws_iam_role.lambda_entry_archiver.name
}
