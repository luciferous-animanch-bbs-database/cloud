resource "aws_pipes_pipe" "insert_archived_entry2" {
  source   = aws_dynamodb_table.entry_archives.stream_arn
  target   = aws_sqs_queue.inert_archived_entry.arn
  role_arn = aws_iam_role.pipes_insert_archived_entry.arn

  source_parameters {
    dynamodb_stream_parameters {
      starting_position = "TRIM_HORIZON"
    }

    filter_criteria {
      filter {
        pattern = jsonencode({
          eventName = ["INSERT"]
        })
      }
    }
  }
}
