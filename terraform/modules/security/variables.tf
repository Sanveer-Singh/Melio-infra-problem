variable "vpc_id" {
  description = "VPC ID for security group creation"
  type        = string
}

variable "name_prefix" {
  description = "Resource naming prefix (e.g. melio-devops-dev)"
  type        = string
}

variable "artifact_bucket_arn" {
  description = "ARN of the S3 artifact bucket for IAM policy"
  type        = string
}

variable "newsfeed_service_token" {
  description = "Authentication token for the newsfeed service (stored in SSM SecureString)"
  type        = string
  sensitive   = true
}

variable "ssh_cidr" {
  description = "CIDR block for optional SSH access; empty string disables SSH rules"
  type        = string
  default     = ""
}
