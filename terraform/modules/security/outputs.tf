output "alb_security_group_id" {
  description = "Security group ID for the ALB"
  value       = aws_security_group.alb.id
}

output "frontend_security_group_id" {
  description = "Security group ID for the frontend EC2 instance"
  value       = aws_security_group.frontend.id
}

output "backend_security_group_id" {
  description = "Security group ID for backend EC2 instances"
  value       = aws_security_group.backend.id
}

output "instance_profile_name" {
  description = "IAM instance profile name for EC2 instances"
  value       = aws_iam_instance_profile.app_instance.name
}

output "iam_role_arn" {
  description = "ARN of the IAM role attached to EC2 instances"
  value       = aws_iam_role.app_instance.arn
}

output "ssm_parameter_name" {
  description = "SSM parameter name for the newsfeed service token"
  value       = aws_ssm_parameter.newsfeed_service_token.name
}

output "ssm_parameter_arn" {
  description = "ARN of the SSM parameter (sensitive)"
  value       = aws_ssm_parameter.newsfeed_service_token.arn
  sensitive   = true
}
