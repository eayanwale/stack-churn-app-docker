terraform {
  required_version = ">= 0.12"

  backend "s3" {
    bucket  = "enoch-tf-state-bucket"
    key     = "stackit-churn-app/terraform.tfstate"
    region  = "us-east-1"
    profile = "stackprog-dev"
  }
}
