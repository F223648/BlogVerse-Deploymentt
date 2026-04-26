output "controller_public_ip" {
  value = aws_instance.jenkins_controller.public_ip
}

output "controller_url" {
  value = "http://${aws_instance.jenkins_controller.public_ip}:8080"
}

output "agent_private_ip" {
  value = aws_instance.jenkins_agent.private_ip
}

output "agent_sg_id" {
  value = aws_security_group.jenkins_agent_sg.id
}

output "agent_instance_profile_name" {
  value = aws_iam_instance_profile.jenkins_agent_profile.name
}
