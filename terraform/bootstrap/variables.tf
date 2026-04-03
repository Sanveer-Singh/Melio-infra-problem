variable "region" {
  description = "AWS region for all bootstrap resources"
  type        = string
  default     = "af-south-1"

  validation {
    condition     = contains(["af-south-1", "us-east-1"], var.region)
    error_message = "Region must be af-south-1 (primary) or us-east-1 (fallback)."
  }
}

variable "project_name" {
  description = "Project name used in resource naming"
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
