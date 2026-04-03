variable "name_prefix" {
  description = "Resource name prefix (e.g. melio-devops-dev)"
  type        = string

  validation {
    condition     = length(var.name_prefix) > 0
    error_message = "name_prefix must not be empty."
  }
}

variable "vpc_id" {
  description = "VPC ID for the target group"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for ALB placement (minimum 2 AZs required by AWS)"
  type        = list(string)

  validation {
    condition     = length(var.public_subnet_ids) >= 2
    error_message = "ALB requires subnets in at least 2 availability zones."
  }
}

variable "alb_security_group_id" {
  description = "Security group ID to attach to the ALB"
  type        = string
}

variable "frontend_instance_id" {
  description = "EC2 instance ID of the frontend server to register in the target group"
  type        = string
}
