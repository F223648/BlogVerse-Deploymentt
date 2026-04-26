# Jenkins Setup Guide

## 1. Controller Provisioning
- Provisioned an EC2 instance in the public subnet using Terraform.
- Security Group allows port 8080 (Jenkins UI) and port 22 (SSH) only from my public IP.
- User data script installed: Jenkins LTS, Java 21, Git, Docker, AWS CLI, and Terraform.

## 2. Initial Configuration
- Accessed Jenkins via `http://<CONTROLLER_IP>:8080`.
- Retrieved initial admin password using `sudo cat /var/lib/jenkins/secrets/initialAdminPassword`.
- Installed suggested plugins + Blue Ocean, SonarQube Scanner, and Docker Pipeline.
- Created a dedicated admin user.

## 3. Agent Configuration
- Provisioned a separate EC2 instance in a private subnet.
- Connected the agent (`linux-agent`) to the controller via SSH.
- Configuration:
  - Remote root: `/home/ec2-user/jenkins`
  - Labels: `linux-agent`
  - Launch method: SSH (using `ec2-user` with `assignment3-key.pem`)
- Verified connection via the Nodes dashboard.

## 4. Credentials Added
- `aws-access-key`: AWS Access Key + Secret.
- `github-pat`: GitHub Personal Access Token.
- `sonarqube-token`: Placeholder (to be updated in Task 4).
- `ecr-credentials`: Username/Password (`AWS` / Secret Key).
- `slack-webhook`: Webhook URL for notifications.
