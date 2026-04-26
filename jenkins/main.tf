# Security Group for Jenkins Controller
resource "aws_security_group" "jenkins_controller_sg" {
  name        = "jenkins-controller-sg"
  description = "Security Group for Jenkins Controller"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
    description = "Allow Jenkins UI access from my IP"
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
    description = "Allow SSH from my IP"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name = "jenkins-controller-sg"
  }
}

# Security Group for Jenkins Agent
resource "aws_security_group" "jenkins_agent_sg" {
  name        = "jenkins-agent-sg"
  description = "Security Group for Jenkins Agent"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.jenkins_controller_sg.id]
    description     = "Allow SSH from Jenkins Controller"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name = "jenkins-agent-sg"
  }
}

# IAM Role for Jenkins Agent
resource "aws_iam_role" "jenkins_agent_role" {
  name = "jenkins-agent-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# ECR Push Policy for Jenkins Agent
resource "aws_iam_role_policy" "ecr_push_policy" {
  name = "jenkins-ecr-push-policy"
  role = aws_iam_role.jenkins_agent_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:GetRepositoryPolicy",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:DescribeImages",
          "ecr:BatchGetImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ]
        Resource = "*"
      }
    ]
  })
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "jenkins_agent_profile" {
  name = "jenkins-agent-profile"
  role = aws_iam_role.jenkins_agent_role.name
}

# Jenkins Controller Instance
resource "aws_instance" "jenkins_controller" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.public_subnet_id
  vpc_security_group_ids = [aws_security_group.jenkins_controller_sg.id]
  key_name               = var.key_name

  user_data = <<-EOF
    #!/bin/bash
    sudo yum update -y
    
    # Install Java 17
    sudo yum install -y fontconfig java-17-amazon-corretto-headless

    # Install Git and Docker
    sudo yum install -y git docker
    sudo systemctl enable docker
    sudo systemctl start docker
    sudo usermod -aG docker ec2-user

    # Install Jenkins LTS
    sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
    sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
    sudo yum upgrade -y
    sudo yum install -y jenkins
    sudo systemctl enable jenkins
    sudo systemctl start jenkins

    # Add jenkins to docker group
    sudo usermod -aG docker jenkins
    sudo systemctl restart jenkins

    # Install AWS CLI
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install

    # Install Terraform
    sudo yum install -y yum-utils
    sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
    sudo yum install -y terraform
  EOF

  tags = {
    Name = "jenkins-controller"
  }
}

# Jenkins Agent Instance
resource "aws_instance" "jenkins_agent" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.private_subnet_id
  vpc_security_group_ids = [aws_security_group.jenkins_agent_sg.id]
  key_name               = var.key_name
  iam_instance_profile   = aws_iam_instance_profile.jenkins_agent_profile.name

  user_data = <<-EOF
    #!/bin/bash
    sudo yum update -y
    
    # Install Java 17, Git, nodejs, npm
    sudo yum install -y fontconfig java-17-amazon-corretto-headless git
    curl -fsSL https://rpm.nodesource.com/setup_18.x | sudo bash -
    sudo yum install -y nodejs
    
    # Install Docker
    sudo yum install -y docker
    sudo systemctl enable docker
    sudo systemctl start docker
    sudo usermod -aG docker ec2-user

    # Install AWS CLI
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install

    # Install Terraform
    sudo yum install -y yum-utils
    sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
    sudo yum install -y terraform
    
    # Install Trivy
    curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sudo sh -s -- -b /usr/local/bin
  EOF

  tags = {
    Name = "jenkins-agent"
  }
}
