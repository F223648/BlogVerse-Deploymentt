output "vpc_id" {
  value = module.vpc.vpc_id
}
output "public_subnet_ids" {
  value = module.vpc.public_subnet_ids
}
output "private_subnet_ids" {
  value = module.vpc.private_subnet_ids
}
output "nat_gateway_id" {
  value = module.vpc.nat_gateway_id
}
output "web_server_public_ip" {
  value = module.web_server.public_ip
}
output "alb_dns_name" {
  value = aws_lb.web.dns_name
}
# output "s3_bucket_name" {
#  value = aws_s3_bucket.terraform_state.bucket
# }

output "jenkins_controller_ip" {
  value = module.jenkins.controller_public_ip
}

output "jenkins_controller_url" {
  value = module.jenkins.controller_url
}

output "jenkins_agent_ip" {
  value = module.jenkins.agent_private_ip
}