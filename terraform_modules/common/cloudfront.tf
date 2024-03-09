locals {
  cloudfront = {
    origin = {
      webapp     = "webapp"
      thumbnails = "thumbnails"
      data       = "data"
    }
  }
}

resource "aws_cloudfront_origin_access_control" "cdn" {
  name                              = "cdn"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_response_headers_policy" "webapp" {
  name = "webapp"

  security_headers_config {
    frame_options {
      frame_option = "DENY"
      override     = true
    }

    strict_transport_security {
      access_control_max_age_sec = 31536000
      include_subdomains         = true
      override                   = true
      preload                    = true
    }
  }

  custom_headers_config {
    items {
      header   = "Cache-Control"
      override = true
      value    = "no-store, no-cache"
    }
  }
}

resource "aws_cloudfront_response_headers_policy" "data" {
  name = "data"

  custom_headers_config {
    items {
      header   = "Cache-Control"
      override = true
      value    = "max-age=450"
    }
  }
}

resource "aws_cloudfront_cache_policy" "data" {
  name        = "data-policy"
  default_ttl = 450
  max_ttl     = 900
  min_ttl     = 1

  parameters_in_cache_key_and_forwarded_to_origin {
    enable_accept_encoding_brotli = true
    enable_accept_encoding_gzip   = true

    query_strings_config {
      query_string_behavior = "none"
    }

    cookies_config {
      cookie_behavior = "none"
    }

    headers_config {
      header_behavior = "none"
    }
  }
}

resource "aws_cloudfront_distribution" "cdn" {
  enabled = true

  comment             = "luciferous-animanch-bbs-database"
  default_root_object = "index.html"
  price_class         = "PriceClass_200"
  retain_on_delete    = false
  wait_for_deployment = false
  is_ipv6_enabled     = true

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["JP", "US"]
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  origin {
    domain_name              = module.bucket_cloudfront_webapp.bucket_regional_domain_name
    origin_id                = local.cloudfront.origin.webapp
    origin_access_control_id = aws_cloudfront_origin_access_control.cdn.id
    s3_origin_config {
      origin_access_identity = ""
    }
  }

  origin {
    domain_name              = module.bucket_cloudfront_thumbnails.bucket_regional_domain_name
    origin_id                = local.cloudfront.origin.thumbnails
    origin_access_control_id = aws_cloudfront_origin_access_control.cdn.id
    s3_origin_config {
      origin_access_identity = ""
    }
  }

  origin {
    domain_name              = module.bucket_cloudfront_data.bucket_regional_domain_name
    origin_id                = local.cloudfront.origin.data
    origin_access_control_id = aws_cloudfront_origin_access_control.cdn.id
    s3_origin_config {
      origin_access_identity = ""
    }
  }

  default_cache_behavior {
    allowed_methods            = ["GET", "HEAD"]
    cached_methods             = ["GET", "HEAD"]
    target_origin_id           = local.cloudfront.origin.webapp
    compress                   = true
    viewer_protocol_policy     = "redirect-to-https"
    response_headers_policy_id = aws_cloudfront_response_headers_policy.webapp.id
    cache_policy_id            = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
    origin_request_policy_id   = "88a5eaf4-2fd4-4709-b370-b4c650ea3fcf"
  }

  ordered_cache_behavior {
    allowed_methods          = ["GET", "HEAD"]
    cached_methods           = ["GET", "HEAD"]
    path_pattern             = "/${local.s3.prefix.thumbnails}/*"
    target_origin_id         = local.cloudfront.origin.thumbnails
    compress                 = true
    viewer_protocol_policy   = "https-only"
    cache_policy_id          = "658327ea-f89d-4fab-a63d-7e88639e58f6"
    origin_request_policy_id = "88a5eaf4-2fd4-4709-b370-b4c650ea3fcf"
  }

  ordered_cache_behavior {
    allowed_methods            = ["GET", "HEAD"]
    cached_methods             = ["GET", "HEAD"]
    path_pattern               = "/${local.s3.prefix.data}/*"
    target_origin_id           = local.cloudfront.origin.data
    compress                   = true
    viewer_protocol_policy     = "https-only"
    response_headers_policy_id = aws_cloudfront_response_headers_policy.data.id
    cache_policy_id            = aws_cloudfront_cache_policy.data.id
    origin_request_policy_id   = "88a5eaf4-2fd4-4709-b370-b4c650ea3fcf"
  }
}
