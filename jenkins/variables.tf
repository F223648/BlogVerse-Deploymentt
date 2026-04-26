variable "vpc_id" {
  description = "VPC ID where Jenkins will be deployed"
  type        = string
}

variable "public_subnet_id" {
  description = "Public subnet for the Jenkins Controller"
  type        = string
}

variable "private_subnet_id" {
  description = "Private subnet for the Jenkins Agent"
  type        = string
}

variable "my_ip" {
  description = "Your public IP address (with /32) for accessing Jenkins Controller"
  type        = string
}

variable "ami_id" {
  description = "AMI ID to use for the EC2 instances"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
}

variable "key_name" {
  description = "SSH key pair name"
  type        = string
}
