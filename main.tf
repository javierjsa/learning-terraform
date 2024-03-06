data "aws_ami" "app_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = ["bitnami-tomcat-*-x86_64-hvm-ebs-nami"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["979382823631"] # Bitnami
}

data "aws_vpc" "default" {
  default = true
}

module "blog_vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "dev"
  cidr = "10.0.0.0/16"

  azs             = ["us-west-2a", "us-west-2b", "us-west-2c"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  tags = {  
    Terraform = "true"
    Environment = "dev"
  }
}

resource "aws_instance" "blog" {
  ami           = data.aws_ami.app_ami.id
  instance_type = var.instance_type
  vpc_security_group_ids = [module.security-group.security_group_id]

  subnet_id = module.blog_vpc.public_subnets[0]

  tags = {
    Name = "HelloWorld"
  }
}

module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "9.7.0"

  name = "blog-alb"
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
  name     = "alb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.blog_vpc.vpc_id
}

resource "aws_lb_target_group_attachment" "test" {
  target_group_arn = aws_lb_target_group.blog-tg.arn
  target_id        = aws_instance.blog.id
  port             = 80
}



module "security-group" {
	source  = "terraform-aws-modules/security-group/aws"
	version = "5.1.1"
  name = "blog_new_group"

  vpc_id              = module.blog_vpc.vpc_id

  ingress_rules       = ["http-80-tcp", "https-443-tcp"]
  ingress_cidr_blocks = ["0.0.0.0/0"]

  egress_rules        = ["all-all"]
  egress_cidr_blocks = ["0.0.0.0/0"]
	}

