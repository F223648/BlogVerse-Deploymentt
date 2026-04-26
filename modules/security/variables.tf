variable "vpc_id"      { type = string }
variable "environment" { type = string }
variable "my_ip"       { type = string }
variable "alb_sg_id"   {
  type    = string
  default = ""
}