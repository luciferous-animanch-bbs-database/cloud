locals {
  s3 = {
    prefix = {
      thumbnails = "thumbnails"
      data       = "data"
    }
    key = {
      data = {
        threads = "data/threads.json.zst"
      }
    }
  }
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
# Bucket CloudFront Thumbnails
# ================================================================

module "bucket_cloudfront_thumbnails" {
  source = "../s3_bucket_backend_cloudfront"

  bucket_prefix               = "cloudfront-thumbnails-"
  cloudfront_distribution_arn = aws_cloudfront_distribution.cdn.arn
}

# ================================================================
# Bucket CloudFront Data
# ================================================================

module "bucket_cloudfront_data" {
  source = "../s3_bucket_backend_cloudfront"

  bucket_prefix               = "cloudfront-data-"
  cloudfront_distribution_arn = aws_cloudfront_distribution.cdn.arn
}
