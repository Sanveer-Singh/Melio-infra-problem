# -----------------------------------------------------------------------------
# AL2023 AMI -- region-agnostic, never hardcode AMI IDs
# -----------------------------------------------------------------------------

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# -----------------------------------------------------------------------------
# SSH Key Pair -- demo only; production should use SSM Session Manager
# Private key stored in Terraform state (unencrypted).
# -----------------------------------------------------------------------------

resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "app" {
  key_name   = "${var.name_prefix}-key"
  public_key = tls_private_key.ssh.public_key_openssh

  tags = { Name = "${var.name_prefix}-key" }
}

# -----------------------------------------------------------------------------
# Pre-render nginx config to avoid double-escaping with bash
# -----------------------------------------------------------------------------

locals {
  frontend_port = 8080
  quotes_port   = 8082
  newsfeed_port = 8083

  nginx_conf = templatefile("${path.module}/templates/nginx.conf.tpl", {
    frontend_port = local.frontend_port
  })
}

# -----------------------------------------------------------------------------
# EC2 Instances -- all 3 in same subnet (AZ-a) for low latency
# Dependency: frontend depends on quotes + newsfeed (private_ip references)
# -----------------------------------------------------------------------------

resource "aws_instance" "quotes" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = var.backend_sg_ids
  iam_instance_profile        = var.instance_profile_name
  key_name                    = aws_key_pair.app.key_name
  associate_public_ip_address = true

  user_data = templatefile("${path.module}/templates/quotes.sh.tpl", {
    artifact_bucket = var.artifact_bucket
    quotes_port     = local.quotes_port
  })
  user_data_replace_on_change = true

  tags = { Name = "${var.name_prefix}-quotes" }
}

resource "aws_instance" "newsfeed" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = var.backend_sg_ids
  iam_instance_profile        = var.instance_profile_name
  key_name                    = aws_key_pair.app.key_name
  associate_public_ip_address = true

  user_data = templatefile("${path.module}/templates/newsfeed.sh.tpl", {
    artifact_bucket = var.artifact_bucket
    newsfeed_port   = local.newsfeed_port
  })
  user_data_replace_on_change = true

  tags = { Name = "${var.name_prefix}-newsfeed" }
}

resource "aws_instance" "frontend" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = var.frontend_sg_ids
  iam_instance_profile        = var.instance_profile_name
  key_name                    = aws_key_pair.app.key_name
  associate_public_ip_address = true

  user_data = templatefile("${path.module}/templates/frontend.sh.tpl", {
    artifact_bucket     = var.artifact_bucket
    frontend_port       = local.frontend_port
    quotes_private_ip   = aws_instance.quotes.private_ip
    quotes_port         = local.quotes_port
    newsfeed_private_ip = aws_instance.newsfeed.private_ip
    newsfeed_port       = local.newsfeed_port
    ssm_parameter_name  = var.ssm_parameter_name
    region              = var.region
    nginx_conf          = local.nginx_conf
  })
  user_data_replace_on_change = true

  tags = { Name = "${var.name_prefix}-frontend" }
}
