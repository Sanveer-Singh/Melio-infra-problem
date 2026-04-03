output "state_bucket_name" {
  description = "Name of the S3 bucket storing Terraform remote state"
  value       = aws_s3_bucket.terraform_state.id
}

output "state_bucket_arn" {
  description = "ARN of the S3 state bucket (for IAM policies)"
  value       = aws_s3_bucket.terraform_state.arn
}

output "artifact_bucket_name" {
  description = "Name of the S3 bucket storing build artifacts (JARs, static assets)"
  value       = aws_s3_bucket.artifacts.id
}

output "artifact_bucket_arn" {
  description = "ARN of the S3 artifact bucket (for IAM policies)"
  value       = aws_s3_bucket.artifacts.arn
}

output "region" {
  description = "AWS region where bootstrap resources are deployed"
  value       = var.region
}
