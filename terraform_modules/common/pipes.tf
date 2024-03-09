resource "aws_pipes_pipe" "insert_archived_entry" {
  source   = aws_dynamodb_table.entry_archives.stream_arn
  target   = aws_sqs_queue.inert_archived_entry.arn
  role_arn = aws_iam_role.pipes_dynamodb_to_sqs.arn

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

resource "terraform_data" "insert_thread_event_names" {
  input = ["INSERT"]
}

resource "terraform_data" "insert_thread_start_position" {
  input = "LATEST"
}

resource "aws_pipes_pipe" "insert_thread" {
  source        = aws_dynamodb_table.threads.stream_arn
  target        = aws_sqs_queue.insert_thread.arn
  role_arn      = aws_iam_role.pipes_dynamodb_to_sqs.arn
  desired_state = true ? "RUNNING" : "STOPPED"

  source_parameters {
    dynamodb_stream_parameters {
      starting_position = terraform_data.insert_thread_start_position.output
    }

    filter_criteria {
      filter {
        pattern = jsonencode({
          eventName = terraform_data.insert_thread_event_names.output
        })
      }
    }
  }

  lifecycle {
    replace_triggered_by = [terraform_data.insert_thread_event_names]
  }
}
