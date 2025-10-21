################################################################################
# Version
################################################################################
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
################################################################################
# Providers
################################################################################
provider "aws" {
  region = var.region
}
################################################################################
# Security Groups
################################################################################
resource "aws_security_group" "servers" {
  name        = "${var.name}-sg-servers"
  description = "${var.name}-sg-servers"
  vpc_id      = var.vpc_id

  ingress {
    description     = "MyHomePage"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.lb.id]
  }
  ingress {
    description = "Allow syslog traffic (UDP)"
    from_port   = 514
    to_port     = 514
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow syslog traffic (TCP)"
    from_port   = 514
    to_port     = 514
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # any protocol
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.name}-sg-servers"
    Service = var.service
  }
}

resource "aws_security_group" "lb" {
  name        = "${var.name}-sg-lb"
  description = "${var.name}-sg-lb"
  vpc_id      = var.vpc_id

  ingress {
    description = "MyHomePage"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.name}-sg-lb"
    Service = var.service
  }
}
################################################################################
# Keys
################################################################################
resource "tls_private_key" "key" { #bash "terraform output private_key.key"  to print to standard output
  algorithm = "RSA"
  rsa_bits  = 2048
}

data "tls_public_key" "key" { 
  private_key_pem = tls_private_key.key.private_key_pem
}

resource "aws_key_pair" "key"{ 
  key_name   = var.key_name
  public_key = data.tls_public_key.key.public_key_openssh
}
################################################################################
# Launch Template
################################################################################
variable "dependency_trigger" { 
  description = "A variable to trigger dependency" 
  type = string 
  } 
resource "null_resource" "dependency" { 
  triggers = {
    always_run = "${var.dependency_trigger}" 
    } 
}

data "aws_ami" "latest_amazon_linux_image" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-kernel-*-x86_64-gp2"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "template_file" "user_data" {
  template = file("${path.module}/user_data.sh")

  vars = { #creates an implicit association with my syslog
    syslog_ip = var.syslog_ip
  }
}

resource "aws_launch_template" "app1" { 
  name_prefix   = "app1-J-Tele-Doctor_LT"
  image_id      = data.aws_ami.latest_amazon_linux_image.id  
  instance_type = "t2.micro"

  key_name = aws_key_pair.key.key_name

  vpc_security_group_ids = [aws_security_group.servers.id] 
  
  user_data = base64encode(data.template_file.user_data.rendered)

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name    = "${var.name}-app1_LT"
      Service = var.service
    }
  }

  lifecycle {
    create_before_destroy = true
  }
  depends_on = [ null_resource.dependency]
}
################################################################################
# Target Group
################################################################################
resource "aws_lb_target_group" "app1_tg1" {
  name     = "${var.name}-tg1"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  target_type = "instance"

  health_check {
    enabled             = true
    interval            = 30
    path                = "/"
    protocol            = "HTTP"
    healthy_threshold   = 5
    unhealthy_threshold = 2
    timeout             = 5
    matcher             = "200"
  }

  tags = {
    Name    ="${var.name}-App1TargetGroup1"
    Service = var.service
  }
}
################################################################################
# Load Balancer
################################################################################
resource "aws_lb" "app1_alb" {
  name               = "${var.name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb.id] 
  subnets            = [
    var.subnet1,
    var.subnet2
  ]
  enable_deletion_protection = false
#Lots of death and suffering here, make sure it's false. Prevents terraform from deleting the load balancer, prevents accidental deletions

  tags = {
    Name    = "${var.name}-LoadBalancer"
  }
}
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app1_alb.arn
  port              = 80
  protocol          = "HTTP"



  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app1_tg1.arn
  }
}
################################################################################
# ASG
################################################################################
resource "aws_autoscaling_group" "app1_asg" {
  name_prefix           = "${var.name}-asg"
  min_size              = 1
  max_size              = 1
  desired_capacity      = 1
  vpc_zone_identifier   = [
    var.subnet3,
    var.subnet4
  ]
  health_check_type          = "ELB"
  health_check_grace_period  = 300
  force_delete               = true
  target_group_arns          = [aws_lb_target_group.app1_tg1.arn] 

  launch_template {
    id      = aws_launch_template.app1.id
    version = "$Latest"
  }

  enabled_metrics = ["GroupMinSize", "GroupMaxSize", "GroupDesiredCapacity", "GroupInServiceInstances", "GroupTotalInstances"]

  # Instance protection for launching
  initial_lifecycle_hook {
    name                  = "instance-protection-launch"
    lifecycle_transition  = "autoscaling:EC2_INSTANCE_LAUNCHING"
    default_result        = "CONTINUE"
    heartbeat_timeout     = 60
    notification_metadata = "{\"key\":\"value\"}"
  }

  # Instance protection for terminating
  initial_lifecycle_hook {
    name                  = "scale-in-protection"
    lifecycle_transition  = "autoscaling:EC2_INSTANCE_TERMINATING"
    default_result        = "CONTINUE"
    heartbeat_timeout     = 300
  }

  tag {
    key                 = "Name"
    value               = "${var.name}-ASG"
    propagate_at_launch = true
  }

  tag {
    key                 = "${var.name}-Environment"
    value               = "${var.name}-Production"
    propagate_at_launch = true
  }
}


# Auto Scaling Policy
resource "aws_autoscaling_policy" "app1_scaling_policy" {
  name                   = "${var.name}-cpu-target"
  autoscaling_group_name = aws_autoscaling_group.app1_asg.name

  policy_type = "TargetTrackingScaling"
  estimated_instance_warmup = 120

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 75.0
  }
}

# Enabling instance scale-in protection
resource "aws_autoscaling_attachment" "app1_asg_attachment" {
  autoscaling_group_name = aws_autoscaling_group.app1_asg.name
  lb_target_group_arn    = aws_lb_target_group.app1_tg1.arn
}