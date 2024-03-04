locals {
  s3 = {
    prefix = {
      thumbnails = "thumbnails"
    }
  }
}

resource "aws_s3_bucket" "thumbnails" {
  bucket_prefix = "thumbnails-"
}