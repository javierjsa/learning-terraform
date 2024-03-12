variable "instance_type" {
  description = "Type of EC2 instance to provision"
  default     = "t2.micro"
}

variable "ami_filter"{
  description = "Name filter and owner for AMI"

  type = object({
    name = string
    owner= string
  })

  default = {
      name = "bitnami-tomcat-*-x86_64-hvm-ebs-nami"
      owner = "979382823631"
  } # Bitnami
}


data "aws_vpc" "default" {
  default = true
}

variable "environment" {
  description = "Development environment"
  type = object ({
    name           = string
    network_prefix = string
  })

  default = {
    name = "dev"
    cidr = "10.0"
  }
}

variable "min_size" {
  description = "Min autoscaling group size"
  type = "string"

  default = 1
}

variable "max_size" {
  description = "Max autoscaling group size"
  type = "string"

  default =  3
  
}

