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
# Policy DynamoDB Scan Threads
# ================================================================

data "aws_iam_policy_document" "policy_dynamodb_scan_threads" {
  policy_id = "policy_dynamodb_scan_threads"
  statement {
    sid       = "AllowDynamoDBScanThreads"
    effect    = "Allow"
    actions   = ["dynamodb:Scan"]
    resources = [aws_dynamodb_table.threads.arn]
    condition {
      test = "StringLike"
      values = [
        "https://${aws_cloudfront_distribution.cdn.domain_name}/*",
        "https://cf02.luciferous.link/referer_test/*"
      ]
      variable = "aws:referer"
    }
  }
}

resource "aws_iam_policy" "dynamodb_scan_threads" {
  policy = data.aws_iam_policy_document.policy_dynamodb_scan_threads.json
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

resource "aws_iam_role" "pipes_dynamodb_to_sqs" {
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy_pipes.json
}

resource "aws_iam_role_policy_attachment" "pipes_dynamodb_to_sqs" {
  for_each = {
    a = "arn:aws:iam::aws:policy/service-role/AWSLambdaDynamoDBExecutionRole"
    b = "arn:aws:iam::aws:policy/AmazonSQSFullAccess"
  }
  policy_arn = each.value
  role       = aws_iam_role.pipes_dynamodb_to_sqs.name
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

# ================================================================
# Role Lambda Entry Parser
# ================================================================

resource "aws_iam_role" "lambda_entry_parser" {
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy_lambda.json
}

resource "aws_iam_role_policy_attachment" "lambda_entry_parser" {
  for_each = {
    a = "arn:aws:iam::aws:policy/service-role/AWSLambdaSQSQueueExecutionRole"
    b = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
  }
  policy_arn = each.value
  role       = aws_iam_role.lambda_entry_parser.name
}

# ================================================================
# Role Lambda Thumbnail Downloader
# ================================================================

resource "aws_iam_role" "lambda_thumbnail_downloader" {
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy_lambda.json
}

resource "aws_iam_role_policy_attachment" "lambda_thumbnail_downloader" {
  for_each = {
    a = "arn:aws:iam::aws:policy/service-role/AWSLambdaSQSQueueExecutionRole"
    b = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
    c = "arn:aws:iam::aws:policy/AmazonDynamoDBReadOnlyAccess"
    d = "arn:aws:iam::aws:policy/AmazonSQSFullAccess"
  }
  policy_arn = each.value
  role       = aws_iam_role.lambda_thumbnail_downloader.name
}

# ================================================================
# Role Lambda Threads Dumper
# ================================================================

resource "aws_iam_role" "lambda_threads_dumper" {
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy_lambda.json
}

resource "aws_iam_role_policy_attachment" "lambda_threads_dumper" {
  for_each = {
    a = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
    b = "arn:aws:iam::aws:policy/AmazonDynamoDBReadOnlyAccess"
    c = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
  }
  policy_arn = each.value
  role       = aws_iam_role.lambda_threads_dumper.name
}
