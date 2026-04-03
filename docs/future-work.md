# Future Work

Improvements beyond the current time-boxed dev environment scope, ordered by priority.

---

## Multi-AZ with Auto Scaling Groups [High Priority]

The current deployment places a single EC2 instance per service in one AZ (af-south-1a). This is a single point of failure -- if the instance or AZ goes down, the service is unavailable.

**Implementation path**:
- Create an Auto Scaling Group (ASG) per service with `min_size = 2`, `max_size = 4` across af-south-1a and af-south-1b
- Convert current EC2 instance configurations to Launch Templates (user data, instance type, AMI, SGs carry over directly)
- Register ASG instances with the ALB target group (replace `aws_lb_target_group_attachment` with ASG-managed registration)
- Add scaling policies: target tracking on CPU utilization (e.g., 70% target) and ALB request count per target
- Estimated cost increase: ~2x current EC2 costs (doubling instance count at minimum)

## Private Subnets + NAT Gateway [High Priority]

Backend instances (quotes, newsfeed) are currently in public subnets with public IPs. This exposes unnecessary attack surface even though security groups restrict access.

**Implementation path**:
- Add 2 private subnets (af-south-1a `10.0.3.0/24`, af-south-1b `10.0.4.0/24`)
- Deploy a NAT Gateway in one public subnet for outbound internet access (newsfeed needs RSS feed access; all instances need S3/SSM access)
- Move backend EC2 instances to private subnets; frontend stays in public subnet (ALB target)
- Update route tables: private subnets route `0.0.0.0/0` via NAT Gateway
- Alternatively, use VPC endpoints for S3 and SSM to reduce NAT Gateway traffic and cost
- **Cost**: ~$32/month per NAT Gateway + data processing charges

## TLS Termination (ACM) [High Priority]

The current deployment uses HTTP only. Any data between the user's browser and the ALB is unencrypted.

**Implementation path**:
- Request an ACM certificate for a registered domain (or use ACM for a self-signed cert in dev)
- Add an HTTPS listener (port 443) on the ALB with the ACM certificate
- Add an HTTP listener rule redirecting port 80 to port 443
- Update security groups: ALB ingress on both 80 and 443
- Requires a registered domain name and DNS validation (Route 53 or external DNS)

## CI/CD Pipeline [Medium Priority]

Builds and deployments are currently manual (run scripts locally). This doesn't scale for team development.

**Implementation path**:
- GitHub Actions workflows:
  - **Build**: On push to `main`, run Docker build, upload artifacts to S3
  - **Test**: `make test` in CI before build
  - **Plan**: `terraform plan` on pull requests (comment plan output on PR)
  - **Apply**: `terraform apply` on merge to `main` (manual approval gate)
- Store AWS credentials as GitHub Actions secrets (OIDC preferred over long-lived keys)
- Branch protection on `main` requiring CI pass
- Separate workflows for infrastructure (Terraform) and application (build/deploy)

## Monitoring and Alerting [Medium Priority]

No monitoring exists beyond ALB health checks. Issues are invisible until users report them.

**Implementation path**:
- **CloudWatch Alarms**: CPU utilization > 80%, ALB unhealthy host count > 0, ALB 5xx rate > 1%
- **CloudWatch Logs**: Install CloudWatch Logs agent on EC2 instances to ship journald logs. Enables searching application logs without SSH.
- **Custom metrics**: Memory usage via CloudWatch agent (JVM memory not exposed by default)
- **Alternative**: Prometheus + Grafana stack for richer dashboards and alerting. Higher operational overhead but more flexible for JVM-specific metrics (JMX exporter).
- **Estimated cost**: CloudWatch basic monitoring is free; custom metrics and logs storage add ~$5-10/month

## WAF / GuardDuty / AWS Config [Medium Priority]

No web application firewall, threat detection, or compliance monitoring is in place.

**Implementation path**:
- **WAF**: Attach AWS WAF to the ALB with managed rule groups (Core Rule Set for SQLi/XSS, IP reputation list, rate limiting)
- **GuardDuty**: Enable for the account to detect credential compromise, crypto-mining, unusual API calls
- **AWS Config**: Enable with rules for compliance: all resources tagged (`required-tags`), security groups not open to `0.0.0.0/0` on all ports (`restricted-common-ports`), S3 buckets encrypted (`s3-bucket-server-side-encryption-enabled`)
- **Cost**: WAF ~$5/month base + $1/million requests; GuardDuty ~$4/month for low-volume accounts; Config ~$2/month per active rule

## Multi-Environment Layout [Low Priority]

Only a `dev` environment exists. Staging and production require separate, isolated deployments.

**Implementation path**:
- **Option A -- Directory per environment**: `terraform/environments/dev/`, `terraform/environments/staging/`, `terraform/environments/prod/` each with their own `backend.tf` and `terraform.tfvars`. Modules shared via relative paths.
- **Option B -- Terraform workspaces**: Single directory with `terraform workspace select <env>`. Less isolation but simpler structure. State stored under separate keys in the same S3 bucket.
- Promotion pipeline: deploy to dev → run integration tests → promote to staging → manual approval → production
- Each environment gets its own VPC, security groups, and instances (full isolation)

## Container Migration (ECS/EKS) [Low Priority]

EC2 instances with systemd are operationally heavy. Containers simplify deployment, scaling, and resource isolation.

**Implementation path**:
- **Dockerfiles**: Simple per-service: `FROM amazoncorretto:17-alpine`, `COPY <service>.jar /app/`, `ENTRYPOINT ["java", "-Xmx512m", "-XX:+UseSerialGC", "-jar", "/app/<service>.jar"]`
- **ECS Fargate** (recommended for this scale): No EC2 management, per-task IAM roles, integrated ALB target groups, built-in logging to CloudWatch. ~20% cost premium over EC2 but eliminates OS patching and instance management.
- **EKS**: For teams already invested in Kubernetes. Higher operational overhead but more ecosystem tooling (Helm, ArgoCD, service mesh).
- **ECR**: Store container images in Amazon ECR (private registry, integrated with ECS/EKS IAM)

## SSM Session Manager [Low Priority]

SSH access requires security group rules and key management. SSM Session Manager provides audited, keyless access.

**Implementation path**:
- The IAM role already has SSM permissions for parameter access; add `ssm:StartSession` and `ssmmessages:*` permissions
- Install SSM Agent on EC2 (pre-installed on AL2023)
- Access via: `aws ssm start-session --target <instance-id>`
- Remove SSH security group rules and `aws_key_pair` resource entirely
- All sessions logged in CloudTrail for audit compliance
- **Cost**: Free (included with SSM)
