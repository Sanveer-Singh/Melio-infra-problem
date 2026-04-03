output "vpc_id" {
  description = "ID of the VPC"
  value       = module.networking.vpc_id
}

output "public_subnet_ids" {
  description = "List of all public subnet IDs"
  value       = module.networking.public_subnet_ids
}

output "alb_security_group_id" {
  description = "Security group ID for the ALB"
  value       = module.security.alb_security_group_id
}

output "frontend_security_group_id" {
  description = "Security group ID for the frontend instance"
  value       = module.security.frontend_security_group_id
}

output "backend_security_group_id" {
  description = "Security group ID for backend instances"
  value       = module.security.backend_security_group_id
}

output "instance_profile_name" {
  description = "IAM instance profile name for EC2 instances"
  value       = module.security.instance_profile_name
}
