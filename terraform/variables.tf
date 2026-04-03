variable "region" {
  description = "AWS region for all infrastructure resources"
  type        = string
  default     = "af-south-1"

  validation {
    condition     = contains(["af-south-1", "us-east-1"], var.region)
    error_message = "Region must be af-south-1 (primary) or us-east-1 (fallback)."
  }
}

variable "project_name" {
  description = "Project name used in resource naming and tagging"
  type        = string
  default     = "melio-devops"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]+$", var.project_name))
    error_message = "Project name must be lowercase alphanumeric with hyphens."
  }
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "aws_profile" {
  description = "AWS CLI profile name for authentication"
  type        = string
  default     = "charteracademy"

  validation {
    condition     = length(var.aws_profile) > 0
    error_message = "AWS profile name must not be empty."
  }
}

variable "instance_type" {
  description = "EC2 instance type for all application servers"
  type        = string
  default     = "t3.small"

  validation {
    condition     = can(regex("^t[23]\\.", var.instance_type))
    error_message = "Instance type must be a t2 or t3 family for cost-effective dev workloads."
  }
}

variable "ssh_cidr" {
  description = "CIDR block allowed SSH access (e.g. YOUR_IP/32). Empty string disables SSH."
  type        = string
  default     = ""

  validation {
    condition     = var.ssh_cidr == "" || can(cidrhost(var.ssh_cidr, 0))
    error_message = "ssh_cidr must be a valid CIDR block or empty string."
  }
}

variable "artifact_bucket_arn" {
  description = "ARN of the S3 artifact bucket (from bootstrap output)"
  type        = string

  validation {
    condition     = can(regex("^arn:aws:s3:::", var.artifact_bucket_arn))
    error_message = "artifact_bucket_arn must be a valid S3 bucket ARN (arn:aws:s3:::bucket-name)."
  }
}

variable "newsfeed_service_token" {
  description = "Authentication token for the newsfeed service (pass via -var or TF_VAR_, never in tfvars)"
  type        = string
  sensitive   = true
}
