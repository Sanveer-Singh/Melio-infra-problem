terraform {
  # Backend blocks only accept literals -- no variable interpolation allowed.
  # Bucket/table names must match bootstrap output (terraform/bootstrap/).
  # Account ID 542088537418 from: aws sts get-caller-identity --profile charteracademy
  backend "s3" {
    bucket         = "melio-devops-dev-tfstate-542088537418"
    key            = "infrastructure/terraform.tfstate"
    region         = "af-south-1"
    encrypt        = true
    dynamodb_table = "melio-devops-dev-terraform-locks"
    profile        = "charteracademy"
  }
}
