## Infrastructure as code

### Resources

Resources are the building blocks of Terraform. Once resources are defined, Terraform figures out how to create them. Resources share a common syntax. However, each provider has different resource types and slightly different options. A provider is not a resource, is what gives access to resources. A provider must be included so that Terraform knows where resources should go.


	provider "aws" {
		profile = "default"
		region = "us-west-2"
	}


A simple resource to focus on syntax:

	resource "aws_s3_bucket" "tf-course" {
		bucket = "samuelson-terraform"
		acls =   "private"
	}


	<resource keyword> "<resource type>" "<resource name>" {
		bucket = "<parameter naming the s3 bucket in AWS>"
		acl = "<parameter defining the bucket scope>"	
	}


### Basic resource types

Basic resource types used throughout the course, will go into detail later on. Public-facing s3 webpage:


	resource "aws_s3_bucket" "example" {
		bucket = "learning-terraform"
		acl = "public-read"
		policy = file("policy.json")
	}


	resource "aws_s3_bucket_website_configuration" "example" {
		bucket = aws_s3_bucket.example.bucket
		index_document {
			suffix = "index.html"	
		}
	}


Defining the website configuration as a separate resource, allows modifying and deleting it without the risk of affecting the data contained within the bucket.

Define a virtual private cloud:

	resource "aws_vpc" "QA" {
		cidr_block = "10.0.0.0/16"
	}


	resource "aws_vpc" "Staging" {
		cidr_block = "10.1.0.0/16"
	}

Define a security group:

	resource "aws_security_group" "allow_tls" {
		ingress {
			from_port = 443
			to_port = 443
			protocol = "tcp"
			cidr_blocks = ["1.2.3.4/32"]	
		}
		egress {
			from_port = 0
			to_port = 0
			protocol = "-1"
		}
	}

The configuration of the _egress_ section allows outbound traffic of any protocol on any port. Just as in the case of buckets and website configuration, security group definitio and rule defintion can be separated.

	resource "aws_security_group" "allow_tls" { }

	resource "aws_security_group_rule" "https_inbound" {
		type = "ingress"
		from_port = 443
		to_port = 443
		protocol = "tcp"
		cidr_blocks = ["1.2.3.4/32"]
		security_group_id = aws_security_group.allow_tls.id	
	}

EC2 instance definition using a variable instead of a hardcoded value for the AMI:

	resource "aws_instance" "blog" {
		ami = data.aws_ami.ubuntu.id
		instance_type = "t3.nano"
	}
	
The variable can be defined in a static way, or by means of Terraform code that looks for the latest Ubuntu AMI.

Definition of an elastic IP:

	resource "aws_eip" "blog" {
		instance = aws_instance.blog.id
		vpc = true
	}

There is no name collision between the ec2 instance definition an the elastic ip, because they are different resource types.

### Terraform style

Some of Terraform style conventions. Indentation consists of two spaces instead of a tab. Meta-arguments  define how you want Terraform to interpret your code and also dependencies among resources. In the following code, _count_ is a meta-argument.

	resource "aws_instance" "web" {
		count = 2
		ami = "abc123"
		instance_type = "t2.micro"
		network_interface {
			...
		}

		lifecyle {
			creat_before_destroy = true
		}

	}

Meta-arguments can are either single meta-arguments, such as _count_, or block meta-arguments, such as _lifecycle_. Block meta-arguments should go at the end of the definition. Also, use blank lines to separate meta-arguments from arguments (in this case: _ami_, _instance type_) for clarity. Group single arguments together. Line up equal signs. Ultimate goal is readability.


### Modules

TF feature that allows combining code into a logical group, so the resources it contains can be managed together. Once a subset of code has been bundled, it can be passed in arguments. Modules work like custom resoucers. The default module is known as root.

Lets say there is a _web_server_ module:

	module "web_server" {
		source = "./modules/servers" // where to find it

		web_ami = "ami-12345
		server_name = "prod-web"
	}

Now let's configure the parameters inside the module.

	variable "web_ami" {
		type = string
		default = "ami-abc123"
	}

	variable "server_name" {
		type = string
	}

Modules can also output values. Data within a module cannot be accessed unless it is declared as an output.

	output "instance_public_ip" {
		value = aws_instance.web_app.public_ip
	}

	output "app_bucket" {
		value = aws_s3_bucket.web_app.bucket
	}

How to reference the output:

	resource "aws_route53_record" "www" {
		name = "www.example.com"
		zone_id = aws_route53_zone.main.zone_id
		type = "A"
		ttl = "300"
		record = [module.web_server.instance_public_ip]
	}

Bare minimum elements required to create a module:

- _main.tf_, containing the code for the module
- _variables.tf_, containing the input variables
- _outputs.tf_, containing the output values
- README.md, need not document input and output, that documentation is auto-generated.

Some other module features:

- Remote modules. It is possible to use remote module sources (s3, git).
- Modules feature versioning.
- A module may include a provider block and even set a specific version for that provider. Better set it in the root module, unless it is required.
- Terraform registry _registry.terraform.oi_, premade modules to manage all sorts of infrastructure.

### Terraform registry: providers

Providers available for all major cloud providers.

_data sources_: how to get information about your deployed infrastructure.

### Terraform registry: modules

First thing to look at is the provision instructions. For instance, these are the instructions for the security-group module

	module "security-group" {
		source  = "terraform-aws-modules/security-group/aws"
		version = "5.1.1"
	}

This module allows using predefined rules. Instead of defining a security group from scratch, then the rules and then linking the rules to the SG, this modules allows the following:

	module "security-group" { //this can be changed to an arbitrary name
		source              = "terraform-aws-modules/security-group/aws"
		version             = "5.1.1"
		name                = "blog_new_group"

		vpc_id              = data.aws_vpc.default.id

		ingress_rules       = ["http-80-tcp", "https-443-tcp"]
		ingress_cidr_blocks = ["0.0.0.0/0"]

		egress_rules        = ["all-all"]
		egress_cidr_blocks  = ["0.0.0.0/0"]

	}

Input names can be found at the output section of the documentation. Now let's add this security group to the EC2 instance.

	resource "aws_instance" "blog" {
		ami           = data.aws_ami.app_ami.id
		instance_type = var.instance_type
		
		vpc_security_group_ids = [module.security-group.security_group_id]

		tags = {
			Name = "HelloWorld"
		}
	}

## Advanced topics

### Get ready to scale

Add a load balancer to the ec2 instances. Start off with the documentation example from the terraform registry.


	module "alb" {
		source = "terraform-aws-modules/alb/aws"

		name    = "blog-alb"
		vpc_id  = "vpc-abcde012"
		subnets = ["subnet-abcde012", "subnet-bcde012a"]

		# Security Group
		security_group_ingress_rules = {
			all_http = {
			from_port   = 80
			to_port     = 80
			ip_protocol = "tcp"
			description = "HTTP web traffic"
			cidr_ipv4   = "0.0.0.0/0"
			}
			all_https = {
			from_port   = 443
			to_port     = 443
			ip_protocol = "tcp"
			description = "HTTPS web traffic"
			cidr_ipv4   = "0.0.0.0/0"
			}
		}
		security_group_egress_rules = {
			all = {
			ip_protocol = "-1"
			cidr_ipv4   = "10.0.0.0/16"
			}
		}

		access_logs = {
			bucket = "my-alb-logs"
		}

		listeners = {
			ex-http-https-redirect = {
			port     = 80
			protocol = "HTTP"
			redirect = {
				port        = "443"
				protocol    = "HTTPS"
				status_code = "HTTP_301"
			}
			}
			ex-https = {
			port            = 443
			protocol        = "HTTPS"
			certificate_arn = "arn:aws:iam::123456789012:server-certificate/test_cert-123456789012"

			forward = {
				target_group_key = "ex-instance"
			}
			}
		}

		target_groups = {
			ex-instance = {
			name_prefix      = "h1"
			protocol         = "HTTP"
			port             = 80
			target_type      = "instance"
			}
		}

		tags = {
			Environment = "Development"
			Project     = "Example"
		}
	}

