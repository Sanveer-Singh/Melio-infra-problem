data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# -----------------------------------------------------------------------------
# Security Groups (3 base SGs + standalone rules)
# Using aws_vpc_security_group_ingress_rule / egress_rule per provider ~> 6.0
# recommended pattern -- avoids circular deps and allows granular management.
# -----------------------------------------------------------------------------

# --- ALB Security Group ---

resource "aws_security_group" "alb" {
  name        = "${var.name_prefix}-alb-sg"
  description = "Security group for the Application Load Balancer"
  vpc_id      = var.vpc_id

  tags = { Name = "${var.name_prefix}-alb-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http_in" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP from internet"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "alb_to_frontend" {
  security_group_id            = aws_security_group.alb.id
  description                  = "Forward to frontend on port 80"
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
  referenced_security_group_id = aws_security_group.frontend.id
}

# --- Frontend Security Group ---

resource "aws_security_group" "frontend" {
  name        = "${var.name_prefix}-frontend-sg"
  description = "Security group for the frontend EC2 instance"
  vpc_id      = var.vpc_id

  tags = { Name = "${var.name_prefix}-frontend-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "frontend_from_alb" {
  security_group_id            = aws_security_group.frontend.id
  description                  = "HTTP from ALB"
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
  referenced_security_group_id = aws_security_group.alb.id
}

resource "aws_vpc_security_group_ingress_rule" "frontend_ssh" {
  count = var.ssh_cidr != "" ? 1 : 0

  security_group_id = aws_security_group.frontend.id
  description       = "SSH access for debugging"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = var.ssh_cidr
}

resource "aws_vpc_security_group_egress_rule" "frontend_all_out" {
  security_group_id = aws_security_group.frontend.id
  description       = "All outbound traffic"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# --- Backend Security Group ---

resource "aws_security_group" "backend" {
  name        = "${var.name_prefix}-backend-sg"
  description = "Security group for backend EC2 instances (quotes + newsfeed)"
  vpc_id      = var.vpc_id

  tags = { Name = "${var.name_prefix}-backend-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "backend_quotes" {
  security_group_id            = aws_security_group.backend.id
  description                  = "Quotes service from frontend"
  ip_protocol                  = "tcp"
  from_port                    = 8082
  to_port                      = 8082
  referenced_security_group_id = aws_security_group.frontend.id
}

resource "aws_vpc_security_group_ingress_rule" "backend_newsfeed" {
  security_group_id            = aws_security_group.backend.id
  description                  = "Newsfeed service from frontend"
  ip_protocol                  = "tcp"
  from_port                    = 8083
  to_port                      = 8083
  referenced_security_group_id = aws_security_group.frontend.id
}

resource "aws_vpc_security_group_ingress_rule" "backend_ssh" {
  count = var.ssh_cidr != "" ? 1 : 0

  security_group_id = aws_security_group.backend.id
  description       = "SSH access for debugging"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = var.ssh_cidr
}

resource "aws_vpc_security_group_egress_rule" "backend_all_out" {
  security_group_id = aws_security_group.backend.id
  description       = "All outbound traffic (newsfeed needs RSS, quotes uniform rule)"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# -----------------------------------------------------------------------------
# IAM -- Role, inline policy, instance profile
# -----------------------------------------------------------------------------

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "app_permissions" {
  statement {
    sid       = "S3ArtifactAccess"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${var.artifact_bucket_arn}/*"]
  }

  statement {
    sid       = "S3ArtifactList"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [var.artifact_bucket_arn]
  }

  statement {
    sid     = "SSMParameterRead"
    effect  = "Allow"
    actions = ["ssm:GetParameter"]
    resources = [
      "arn:aws:ssm:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:parameter/app/*"
    ]
  }
}

resource "aws_iam_role" "app_instance" {
  name               = "${var.name_prefix}-app-instance-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = { Name = "${var.name_prefix}-app-instance-role" }
}

resource "aws_iam_role_policy" "app_permissions" {
  name   = "${var.name_prefix}-app-permissions"
  role   = aws_iam_role.app_instance.id
  policy = data.aws_iam_policy_document.app_permissions.json
}

resource "aws_iam_instance_profile" "app_instance" {
  name = "${var.name_prefix}-app-instance-profile"
  role = aws_iam_role.app_instance.name

  tags = { Name = "${var.name_prefix}-app-instance-profile" }
}

# -----------------------------------------------------------------------------
# SSM Parameter -- newsfeed service token (SecureString, default AWS managed key)
# -----------------------------------------------------------------------------

resource "aws_ssm_parameter" "newsfeed_service_token" {
  name        = "/app/newsfeed-service-token"
  description = "Authentication token for the newsfeed service"
  type        = "SecureString"
  value       = var.newsfeed_service_token

  tags = { Name = "${var.name_prefix}-newsfeed-token" }
}
