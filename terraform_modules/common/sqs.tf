resource "aws_sqs_queue" "inert_archived_entry" {
  name_prefix                = "insert_archived_entry_"
  visibility_timeout_seconds = 150
}
