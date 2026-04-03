output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "List of all public subnet IDs (used by ALB for multi-AZ)"
  value       = aws_subnet.public[*].id
}

output "public_subnet_a_id" {
  description = "ID of public subnet in AZ-a (compute instances placed here)"
  value       = aws_subnet.public[0].id
}

output "public_subnet_b_id" {
  description = "ID of public subnet in AZ-b (ALB presence for 2-AZ requirement)"
  value       = aws_subnet.public[1].id
}
