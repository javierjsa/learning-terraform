variable "instance_type" {
  description = "Type of EC2 instance to provision"
  default     = "t2.micro"
}

variable "ami_filter"{
  description = "Name filter and owner for AMI"

  type = object({
    values = string
    owner= string
  })

  default = {
      values = "bitnami-tomcat-*-x86_64-hvm-ebs-nami"
      owner = "979382823631"
  } # Bitnami
}

variable "environment" {
  description = "Development environment"
  type = object ({
    name           = string
    network_prefix = string
  })

  default = {
    name = "dev"
    network_prefix = "10.0"
  }
}

variable "min_size" {
  description = "Min autoscaling group size"
  type = number

  default = 1
}

variable "max_size" {
  description = "Max autoscaling group size"
  type = number

  default =  3
  
}

