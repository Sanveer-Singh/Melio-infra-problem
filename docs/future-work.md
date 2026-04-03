# Future Work

Improvements beyond the current time-boxed dev environment scope.

## Multi-AZ with Auto Scaling Groups

<!-- ASG per service, min 2 instances across af-south-1a and af-south-1b -->

## Private Subnets + NAT Gateway

<!-- Move backend instances to private subnets; NAT for outbound (RSS feeds) -->

## TLS Termination (ACM)

<!-- ACM certificate on ALB, HTTPS listener, redirect HTTP -> HTTPS -->

## CI/CD Pipeline

<!-- GitHub Actions: build -> test -> upload artifacts -> terraform plan/apply -->

## Monitoring and Alerting

<!-- CloudWatch alarms, CloudWatch Logs agent or Prometheus+Grafana -->

## WAF / GuardDuty / AWS Config

<!-- WAF on ALB, GuardDuty for threat detection, Config for compliance rules -->

## Multi-Environment Layout

<!-- Terraform workspaces or directory-per-env (dev, staging, production) -->

## Container Migration (ECS/EKS)

<!-- ECS Fargate or EKS for container orchestration; Dockerfile per service -->

## SSM Session Manager

<!-- Replace direct SSH with Session Manager for audited, keyless access -->
