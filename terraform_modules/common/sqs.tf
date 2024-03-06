resource "aws_sqs_queue" "inert_archived_entry" {
  name_prefix                = "insert_archived_entry_"
  visibility_timeout_seconds = 150
}

resource "aws_sqs_queue" "insert_thread" {
  name_prefix                = "insert_thread_"
  visibility_timeout_seconds = 210
}
