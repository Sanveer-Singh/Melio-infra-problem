locals {
  name_prefix          = "${var.project_name}-${var.environment}"
  artifact_bucket_name = replace(var.artifact_bucket_arn, "arn:aws:s3:::", "")
}
