output "vpc_id" {
  description = "ID of the VPC"
  value       = module.networking.vpc_id
}

output "public_subnet_ids" {
  description = "List of all public subnet IDs"
  value       = module.networking.public_subnet_ids
}
