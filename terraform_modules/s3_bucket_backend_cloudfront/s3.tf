resource "aws_s3_bucket" "bucket" {
  bucket_prefix = var.bucket_prefix
}

data "aws_iam_policy_document" "thumbnails" {
  policy_id = "bucket_policy_thumbnails"
  statement {
    sid    = "BucketPolicyThumbnails"
    effect = "Allow"
    principals {
      identifiers = ["cloudfront.amazonaws.com"]
      type        = "Service"
    }
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.bucket.arn}/*"]
    condition {
      test     = "StringEquals"
      values   = [var.cloudfront_distribution_arn]
      variable = "AWS:SourceArn"
    }
  }
}

resource "aws_s3_bucket_policy" "bucket" {
  bucket = aws_s3_bucket.bucket.id
  policy = data.aws_iam_policy_document.thumbnails.json
}