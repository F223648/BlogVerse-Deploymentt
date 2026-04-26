variable "ami_id" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "security_group_ids" {
  type = list(string)
}

variable "key_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "user_data" {
  type    = string
  default = ""
}

variable "is_public" {
  type    = bool
  default = true
}