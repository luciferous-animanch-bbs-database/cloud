locals {
  sqs = {
    visibility_timeout = {
      dead_letter_queue = 30
    }
  }
}

resource "aws_sqs_queue" "inert_archived_entry" {
  name_prefix                = "insert_archived_entry_"
  visibility_timeout_seconds = 150
}

resource "aws_sqs_queue" "insert_thread" {
  name_prefix                = "insert_thread_"
  visibility_timeout_seconds = 210

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq_insert_thread.arn
    maxReceiveCount     = 5
  })
}

resource "aws_sqs_queue" "dlq_insert_thread" {
  name_prefix                = "dlq_insert_thread_"
  visibility_timeout_seconds = local.sqs.visibility_timeout.dead_letter_queue
}

resource "aws_sqs_queue_redrive_allow_policy" "dlq_insert_thread" {
  queue_url = aws_sqs_queue.dlq_insert_thread.url
  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue"
    sourceQueueArns   = [aws_sqs_queue.insert_thread.arn]
  })
}
