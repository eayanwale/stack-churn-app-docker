variable "AWS_REGION" {
  type    = string
  default = "us-east-1"
}

variable "VPC_ID" {
  type    = string
  default = "vpc-0513533f2f1efbfbd"
}

variable "INSTANCE_ROLE" {
  type    = string
  default = "arn:aws:iam::524558748095:instance-profile/sagemaker-policy"
}

variable "REPO_URL" {
  type    = string
  default = "524558748095.dkr.ecr.us-east-1.amazonaws.com/stackit-churn-repo"
}

variable "CONTAINER_NAME" {
  type    = string
  default = "churn"
}

variable "SUBNET_A" {
  type    = string
  default = "subnet-0cd407c60e5fc2301"
}

variable "SUBNET_B" {
  type    = string
  default = "subnet-004ef57820b789ae3"
}

variable "AMI_NAME_PREFIX" {
  type    = string
  default = "stack-churn-app" # must match ami_name in packer/image.pkr.hcl
}