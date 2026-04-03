terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # No backend block -- bootstrap uses LOCAL state intentionally.
  # The S3 state bucket doesn't exist yet when bootstrap runs.
  # State file: terraform/bootstrap/terraform.tfstate (gitignored).
  # WARNING: losing this file before teardown means manual S3 cleanup.
}

provider "aws" {
  profile = var.aws_profile
  region  = var.region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}
