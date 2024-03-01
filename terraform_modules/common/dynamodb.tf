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