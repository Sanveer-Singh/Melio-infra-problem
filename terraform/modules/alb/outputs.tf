output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer (use as application URL)"
  value       = aws_lb.main.dns_name
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.main.arn
}

output "alb_zone_id" {
  description = "Canonical hosted zone ID of the ALB (for Route53 alias records)"
  value       = aws_lb.main.zone_id
}

output "target_group_arn" {
  description = "ARN of the frontend target group"
  value       = aws_lb_target_group.frontend.arn
}
