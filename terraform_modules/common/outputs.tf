output "s3_bucket_webapp" {
  value = module.bucket_cloudfront_webapp.bucket_name
}

output "cloudfront_url" {
  value = "https://${aws_cloudfront_distribution.cdn.domain_name}/"
}
