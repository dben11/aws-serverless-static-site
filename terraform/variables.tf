variable "aws_region" {
  description = "AWS region for the S3 bucket"
  type        = string
  default     = "eu-west-1"
}

variable "bucket_name" {
  description = "Globally unique name for the S3 bucket"
  type        = string
  # Note: Since bucket names must be globally unique, you might need to add random numbers to this when you deploy.
  default     = "dben-learning-static-2026-tf" 
}
