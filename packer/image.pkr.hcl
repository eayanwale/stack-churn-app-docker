packer {
  required_plugins {
    amazon = {
      version = ">= 1.3.0"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

variable "aws_source_ami" {
  default = "al2023-ami-2023*-x86_64"
}

variable "aws_instance_type" {
  default = "t2.small"
}

variable "ami_name" {
  default = "stack-churn-app"
}

variable "component" {
  default = "churn"
}


variable "aws_accounts" {
  type = list(string)
  # default= ["577701061234","560089993749"]
  default= ["524558748095"]
}

variable "ami_regions" {
  type = list(string)
  default =["us-east-1"]
}

variable "aws_region" {
  default = "us-east-1"
}

data "amazon-ami" "al2023" {
  region = "${var.aws_region}"
  filters = {
    name                = "al2023-ami-2023*-x86_64"
    root-device-type    = "ebs"
    virtualization-type = "hvm"
  }
  owners      = ["amazon"]
  most_recent = true
}




locals { timestamp = regex_replace(timestamp(), "[- TZ:]", "") }


# source blocks are generated from your builders; a source can be referenced in
# build blocks. A build block runs provisioners and post-processors on a
# source.


source "amazon-ebs" "amazon_ebs" {
  # assume_role {
  #   role_arn     = "arn:aws:iam::524558748095:role/Engineer"
  # }
  ami_name                = "${var.ami_name}-${local.timestamp}"
  ami_regions             = "${var.ami_regions}"
  ami_users               = "${var.aws_accounts}"
  snapshot_users          = "${var.aws_accounts}"
  encrypt_boot            = false
  instance_type           = "${var.aws_instance_type}"
  launch_block_device_mappings {
    delete_on_termination = true
    device_name           = "/dev/xvda"
    encrypted             = false
    volume_size           = 10
    volume_type           = "gp2"
  }
  region                  = "${var.aws_region}"
  source_ami              = "${data.amazon-ami.al2023.id}"
  ssh_pty                 = true
  ssh_timeout             = "5m"
  ssh_username            = "ec2-user"
}


# a build block invokes sources and runs provisioning steps on them.
build {
  sources = ["source.amazon-ebs.amazon_ebs"]
  provisioner "shell" {
    script = "${path.root}/setup.sh"
  }
}
