output "frontend_instance_id" {
  description = "Instance ID of the frontend EC2 (needed by ALB target group)"
  value       = aws_instance.frontend.id
}

output "frontend_private_ip" {
  description = "Private IP of the frontend instance"
  value       = aws_instance.frontend.private_ip
}

output "frontend_public_ip" {
  description = "Public IP of the frontend instance (fallback if ALB not deployed)"
  value       = aws_instance.frontend.public_ip
}

output "quotes_private_ip" {
  description = "Private IP of the quotes instance"
  value       = aws_instance.quotes.private_ip
}

output "quotes_public_ip" {
  description = "Public IP of the quotes instance (SSH debugging)"
  value       = aws_instance.quotes.public_ip
}

output "newsfeed_private_ip" {
  description = "Private IP of the newsfeed instance"
  value       = aws_instance.newsfeed.private_ip
}

output "newsfeed_public_ip" {
  description = "Public IP of the newsfeed instance (SSH debugging)"
  value       = aws_instance.newsfeed.public_ip
}

output "key_pair_name" {
  description = "Name of the SSH key pair registered in AWS"
  value       = aws_key_pair.app.key_name
}

output "private_key_pem" {
  description = "SSH private key in PEM format (demo only -- stored in state)"
  value       = tls_private_key.ssh.private_key_pem
  sensitive   = true
}
