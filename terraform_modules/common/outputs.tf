output "s3_bucket_webapp" {
  value = module.bucket_cloudfront_webapp.bucket_name
}

output "cloudfront_url" {
  value = "https://${aws_cloudfront_distribution.cdn.domain_name}/"
}

output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.cdn.id
}