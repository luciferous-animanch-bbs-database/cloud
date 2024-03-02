resource "aws_dynamodb_table" "entry_archives" {
  attribute {
    name = "url"
    type = "S"
  }

  hash_key         = "url"
  name             = "entry_archives"
  billing_mode     = "PAY_PER_REQUEST"
  stream_enabled   = true
  stream_view_type = "KEYS_ONLY"
}

resource "aws_dynamodb_table" "database" {
  attribute {
    name = "category"
    type = "S"
  }

  attribute {
    name = "sort_key"
    type = "S"
  }

  hash_key     = "category"
  range_key    = "sort_key"
  name         = "database"
  billing_mode = "PAY_PER_REQUEST"
}
