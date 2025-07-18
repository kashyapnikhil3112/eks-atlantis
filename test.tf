# Simple S3 bucket for testing Atlantis
resource "aws_s3_bucket" "atlantis_test" {
  bucket = "atlantis-test-"
  
  tags = {
    Name        = "Atlantis Test Bucket"
    Environment = "test"
    ManagedBy   = "atlantis"
  }
}

resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

output "test_bucket_name" {
  description = "Name of the test S3 bucket"
  value       = aws_s3_bucket.atlantis_test.bucket
}
