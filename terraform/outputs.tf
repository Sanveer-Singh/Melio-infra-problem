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

# --- Compute outputs ---

output "frontend_instance_id" {
  description = "Instance ID of the frontend EC2 (needed by ALB)"
  value       = module.compute.frontend_instance_id
}

output "frontend_public_ip" {
  description = "Public IP of the frontend instance (fallback access)"
  value       = module.compute.frontend_public_ip
}

output "quotes_public_ip" {
  description = "Public IP of the quotes instance (SSH debugging)"
  value       = module.compute.quotes_public_ip
}

output "newsfeed_public_ip" {
  description = "Public IP of the newsfeed instance (SSH debugging)"
  value       = module.compute.newsfeed_public_ip
}

output "ssh_private_key" {
  description = "SSH private key PEM (demo only -- sensitive)"
  value       = module.compute.private_key_pem
  sensitive   = true
}

output "ssh_key_pair_name" {
  description = "Name of the SSH key pair in AWS"
  value       = module.compute.key_pair_name
}
