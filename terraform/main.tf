provider "aws" {
  region = var.aws_region
}

# ==========================================
# 1. THE S3 BUCKET (Private Warehouse)
# ==========================================
resource "aws_s3_bucket" "site_bucket" {
  bucket = var.bucket_name
}

# Block ALL public access (The security boundary)
resource "aws_s3_bucket_public_access_block" "site_bucket_pab" {
  bucket                  = aws_s3_bucket.site_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable Versioning (The undo button)
resource "aws_s3_bucket_versioning" "site_bucket_versioning" {
  bucket = aws_s3_bucket.site_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# ==========================================
# 2. THE OAC (The VIP Pass)
# ==========================================
# Note: Terraform calls this "origin_access_control" but it's the exact same OAC feature
resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "oac-${var.bucket_name}"
  description                       = "OAC for static site"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# ==========================================
# 3. THE CLOUDFRONT DISTRIBUTION (The Global Retail Stores)
# ==========================================
resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name              = aws_s3_bucket.site_bucket.bucket_regional_domain_name
    origin_id                = "S3-${var.bucket_name}"
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${var.bucket_name}"

    # Redirect HTTP to HTTPS
    viewer_protocol_policy = "redirect-to-https"

    # Use the AWS Managed CachingOptimized policy (we will look up its ID in a moment)
    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6" 
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

# ==========================================
# 4. THE BUCKET POLICY (The Trust Bridge)
# ==========================================
resource "aws_s3_bucket_policy" "allow_cloudfront" {
  bucket = aws_s3_bucket.site_bucket.id

  # We use a Terraform "jsonencode" to build the policy dynamically. 
  # Notice how it references the CloudFront ARN created above!
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudFrontServicePrincipalReadOnly"
        Effect    = "Allow"
        Principal = { Service = "cloudfront.amazonaws.com" }
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.site_bucket.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.s3_distribution.arn
          }
        }
      }
    ]
  })
}

# ==========================================
# 5. UPLOAD THE WEBSITE FILES
# ==========================================
resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.site_bucket.id
  key          = "index.html"
  source       = "../website/index.html" # Looks in the website folder!
  content_type = "text/html"
  etag         = filemd5("../website/index.html") # <--- The Magic
}
