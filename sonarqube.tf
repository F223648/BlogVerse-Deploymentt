# Task 4: SonarQube Integration
resource "aws_security_group" "sonarqube_sg" {
  name        = "sonarqube-sg"
  description = "Security Group for SonarQube"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.my_ip.response_body)}/32"]
    description = "Allow SonarQube UI access from my IP"
  }

  ingress {
    from_port       = 9000
    to_port         = 9000
    protocol        = "tcp"
    security_groups = [module.jenkins.agent_sg_id]
    description     = "Allow SonarQube from Jenkins Agent"
  }
  
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.my_ip.response_body)}/32"]
    description = "Allow SSH access from my IP"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name = "sonarqube-sg"
  }
}

resource "aws_instance" "sonarqube" {
  ami                    = var.ami_id
  instance_type          = "t3.small"
  subnet_id              = module.vpc.public_subnet_ids[0]
  vpc_security_group_ids = [aws_security_group.sonarqube_sg.id]
  key_name               = aws_key_pair.deployer.key_name

  user_data = <<-EOF
    #!/bin/bash
    sudo yum update -y
    sudo yum install -y docker
    sudo systemctl enable docker
    sudo systemctl start docker
    sudo usermod -aG docker ec2-user

    # Give max virtual memory to elasticsearch inside SonarQube
    sudo sysctl -w vm.max_map_count=262144
    echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf

    # Run SonarQube community edition
    sudo docker run -d --name sonarqube -p 9000:9000 --restart always sonarqube:9.9.4-community
  EOF

  tags = {
    Name = "sonarqube-server"
  }
}

output "sonarqube_url" {
  value = "http://${aws_instance.sonarqube.public_ip}:9000"
}
