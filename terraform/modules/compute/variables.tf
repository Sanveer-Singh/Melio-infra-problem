variable "name_prefix" {
  description = "Prefix for resource naming (e.g. melio-devops-dev)"
  type        = string
}

variable "subnet_id" {
  description = "ID of the public subnet (AZ-a) where all 3 instances are placed"
  type        = string
}

variable "frontend_sg_ids" {
  description = "Security group IDs for the frontend EC2 instance"
  type        = list(string)
}

variable "backend_sg_ids" {
  description = "Security group IDs for backend EC2 instances (quotes + newsfeed)"
  type        = list(string)
}

variable "instance_profile_name" {
  description = "IAM instance profile name granting S3 + SSM access"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for all application servers"
  type        = string
  default     = "t3.small"

  validation {
    condition     = can(regex("^t[23]\\.", var.instance_type))
    error_message = "Instance type must be a t2 or t3 family."
  }
}

variable "artifact_bucket" {
  description = "S3 bucket name containing JARs and static.tgz"
  type        = string
}

variable "ssm_parameter_name" {
  description = "SSM Parameter Store path for NEWSFEED_SERVICE_TOKEN"
  type        = string
  default     = "/app/newsfeed-service-token"
}

variable "region" {
  description = "AWS region (needed for SSM CLI call in user data)"
  type        = string
}

