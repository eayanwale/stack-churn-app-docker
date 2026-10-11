# Newest golden image built by packer/image.pkr.hcl
data "aws_ami" "churn_golden" {
  most_recent = true
  owners      = ["self"]

  filter {
    name   = "name"
    values = ["${var.AMI_NAME_PREFIX}-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_security_group" "allow_ssh_http" {
  name        = "allow_ssh_http"
  description = "Allow SSH and HTTP inbound traffic from anywhere"
  vpc_id      = var.VPC_ID

  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_ssh_http"
  }
}

resource "aws_launch_template" "churn-app-lt" {
  name_prefix   = "stackit-churn-app-lt"
  description   = "Terraform launch template for AL2 Clixx instance"
  image_id      = data.aws_ami.churn_golden.id
  instance_type = "t3.small"
  key_name      = "stack-final-key"

  iam_instance_profile {
    arn = var.INSTANCE_ROLE
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.allow_ssh_http.id]
  }

  user_data = base64encode(templatefile("${path.module}/user-data.tftpl", {
    aws_region     = var.AWS_REGION
    repo_url       = var.REPO_URL
    container_name = var.CONTAINER_NAME
  }))

  tags = {
    name = "stackit-churn-app-lt"
  }
}

resource "aws_autoscaling_group" "churn-app-asg" {
  name                      = "stackit-churn-app-asg"
  max_size                  = 2
  min_size                  = 1
  health_check_type         = "ELB"
  health_check_grace_period = 300
  desired_capacity          = 2
  force_delete              = true
  vpc_zone_identifier       = [var.SUBNET_A, var.SUBNET_B]
  target_group_arns         = [aws_lb_target_group.churn-app-tg.arn]

  instance_refresh {
    strategy = "Rolling"
    preferences {
      auto_rollback          = true
      instance_warmup        = 120
      min_healthy_percentage = 50
    }
  }

  launch_template {
    id = aws_launch_template.churn-app-lt.id
    # A concrete version (not "$Latest") so a new AMI changes this value and
    # triggers the instance_refresh above.
    version = aws_launch_template.churn-app-lt.latest_version
  }

  tag {
    key                 = "Name"
    value               = "stackit-churn-app-instance"
    propagate_at_launch = true
  }
}

resource "aws_lb" "churn-app-lb" {
  name               = "churn-app-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.allow_ssh_http.id]
  subnets            = [var.SUBNET_A, var.SUBNET_B]

  tags = {
    Environment = "production"
  }
}

resource "aws_lb_listener" "lb-lsnr" {
  load_balancer_arn = aws_lb.churn-app-lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.churn-app-tg.arn
  }

  tags = {
    Name = "churn-app-lb-listener"
  }
}

resource "aws_lb_target_group" "churn-app-tg" {
  name     = "churn-app-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.VPC_ID
}

resource "aws_autoscaling_policy" "cpu_target_tracking" {
  name                   = "cpu-target-policy"
  autoscaling_group_name = aws_autoscaling_group.churn-app-asg.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 80.0
  }
}
