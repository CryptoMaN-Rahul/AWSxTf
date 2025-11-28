variable "region"{
    description = "AWS region to deploy to"
    type=string
    default = "us-east-1"

}


variable "vpc_cidr" {
    description = "CIDR block for the VPC"
    type = string
    default = "10.0.0.0/16"
  
}


variable "az" {
    description = "availabilty zone to use"
    type =string
    default="us-east-1a"
  
}

variable "instance_type" {
    description="ec2 instance type"
    type =string
    default = "m5.4xlarge"
  
}


variable "public_subnet_cidr" {
    description = "CIDR block for the public subnet"
    type = string
    default = "10.0.1.0/24"
 }

variable "firewall_subnet_cidr" {
    description = "CIDR block for the firewall subnet"
    type = string
    default = "10.0.2.0/24"
 }
variable "private_subnet_cidr" {
    description = "CIDR block for the private subnet"
    type = string
    default = "10.0.3.0/24"
 }

 variable "private_instance_ami" {
    description = "AMI ID for the private EC2 instance"
    type = string
    default = "ami-0453ec754f44f9a4a" # Amazon Linux 2 AMI in us-east-1
 }