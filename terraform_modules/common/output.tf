output "s3_bucket_webapp" {
  value = aws_s3_bucket.webapp.bucket
}

output "cloudfront_url" {
  value = "https://${aws_cloudfront_distribution.cdn.domain_name}/"
}