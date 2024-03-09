locals {
  s3 = {
    prefix = {
      thumbnails = "thumbnails"
      data       = "data"
    }
    key = {
      data = {
        threads = "data/threads.json"
      }
    }
  }
}

# ================================================================
# Bucket Thumbnails
# ================================================================

resource "aws_s3_bucket" "thumbnails" {
  bucket_prefix = "thumbnails-"
}

data "aws_iam_policy_document" "bucket_policy_thumbnails" {
  policy_id = "bucket_policy_thumbnails"
  statement {
    sid    = "BucketPolicyThumbnails"
    effect = "Allow"
    principals {
      identifiers = ["cloudfront.amazonaws.com"]
      type        = "Service"
    }
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.thumbnails.arn}/*"]
    condition {
      test     = "StringEquals"
      values   = [aws_cloudfront_distribution.cdn.arn]
      variable = "AWS:SourceArn"
    }
  }
}

resource "aws_s3_bucket_policy" "thumbnails" {
  bucket = aws_s3_bucket.thumbnails.id
  policy = data.aws_iam_policy_document.bucket_policy_thumbnails.json
}

# ================================================================
# Bucket WebApp
# ================================================================

resource "aws_s3_bucket" "webapp" {
  bucket_prefix = "webapp-"
}

data "aws_iam_policy_document" "bucket_policy_webapp" {
  policy_id = "bucket_policy_webapp"
  statement {
    sid    = "BucketPolicyWebApp"
    effect = "Allow"
    principals {
      identifiers = ["cloudfront.amazonaws.com"]
      type        = "Service"
    }
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.webapp.arn}/*"]
    condition {
      test     = "StringEquals"
      values   = [aws_cloudfront_distribution.cdn.arn]
      variable = "AWS:SourceArn"
    }
  }
}

resource "aws_s3_bucket_policy" "webapp" {
  bucket = aws_s3_bucket.webapp.id
  policy = data.aws_iam_policy_document.bucket_policy_webapp.json
}

# ================================================================
# Bucket CloudFront WebApp
# ================================================================

module "bucket_cloudfront_webapp" {
  source = "../s3_bucket_backend_cloudfront"

  bucket_prefix               = "cloudfront-webapp-"
  cloudfront_distribution_arn = aws_cloudfront_distribution.cdn.arn
}

# ================================================================
# Bucket CloudFront WebApp
# ================================================================

module "bucket_cloudfront_thumbnails" {
  source = "../s3_bucket_backend_cloudfront"

  bucket_prefix               = "cloudfront-thumbnails-"
  cloudfront_distribution_arn = aws_cloudfront_distribution.cdn.arn
}

# ================================================================
# Bucket CloudFront WebApp
# ================================================================

module "bucket_cloudfront_data" {
  source = "../s3_bucket_backend_cloudfront"

  bucket_prefix               = "cloudfront-data-"
  cloudfront_distribution_arn = aws_cloudfront_distribution.cdn.arn
}
