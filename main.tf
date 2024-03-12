data "aws_ami" "app_ami" {
  most_recent = true

  filter {
    name   = var.ami_filter.name
    values = ["bitnami-tomcat-*-x86_64-hvm-ebs-nami"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = [var.ami_filter.owner]
}

data "aws_vpc" "default" {
  default = true
}

module "blog_vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "${var.environment.name}-vpc"
  cidr = "${var.environment.network_prefix}.0.0/16"

  azs             = ["us-west-2a", "us-west-2b", "us-west-2c"]
  public_subnets  = ["${var.environment.network_prefix}.101.0/24", 
                     "${var.environment.network_prefix}.102.0/24",
                     "${var.environment.network_prefix}.103.0/24"]
  tags = {  
    Terraform = "true"
    Environment = var.environment.name
  }
}

module "autoscaling" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "7.4.1"
  # insert the 1 required variable here
  name = "${var.environment.name}-blog-autoscaling"
  min_size = var.min_size
  max_size = var.max_size

  vpc_zone_identifier = module.blog_vpc.public_subnets
  security_groups     = [module.security-group.security_group_id]
  target_group_arns   = [aws_lb_target_group.blog-tg.arn]

  instance_type       = var.instance_type
  image_id            = data.aws_ami.app_ami.id
}

module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "9.7.0"

  name = "${var.environment.name}-blog-alb"
  load_balancer_type = "application"
  create_security_group = "false"  
  security_groups = [module.security-group.security_group_id]
  vpc_id = module.blog_vpc.vpc_id
  subnets = module.blog_vpc.public_subnets
  enable_deletion_protection = "false"
  }
  
resource "aws_lb_listener" "blog-alb" {
  load_balancer_arn = module.alb.arn
  port              = "80"
  protocol          = "HTTP"

default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.blog-tg.arn
  }
}

resource "aws_lb_target_group" "blog-tg" {
  name     = "${var.environment.name}-alb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.blog_vpc.vpc_id
}

module "security-group" {
	source  = "terraform-aws-modules/security-group/aws"
	version = "5.1.1"
  name = "${var.environment.name}-blog_new_group"

  vpc_id              = module.blog_vpc.vpc_id

  ingress_rules       = ["http-80-tcp", "https-443-tcp"]
  ingress_cidr_blocks = ["0.0.0.0/0"]

  egress_rules        = ["all-all"]
  egress_cidr_blocks = ["0.0.0.0/0"]
	}

