# SSH Key Pair
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "deployer" {
  key_name   = var.key_name
  public_key = tls_private_key.ssh_key.public_key_openssh
}

resource "local_file" "private_key" {
  content         = tls_private_key.ssh_key.private_key_pem
  filename        = "${path.module}/${var.key_name}.pem"
  file_permission = "0400"
}

# VPC Module
module "vpc" {
  source               = "./modules/vpc"
  vpc_cidr             = "10.1.0.0/16"
  public_subnet_cidrs  = ["10.1.1.0/24", "10.1.2.0/24"]
  private_subnet_cidrs = ["10.1.10.0/24", "10.1.11.0/24"]
  environment          = "assignment3"
}

# Security Module
module "security" {
  source      = "./modules/security"
  vpc_id      = module.vpc.vpc_id
  environment = "assignment3"
  my_ip       = "${chomp(data.http.my_ip.response_body)}/32"
}

data "http" "my_ip" {
  url = "https://api.ipify.org"
}

# Web Server EC2 (Task 2)
module "web_server" {
  source             = "./modules/compute"
  ami_id             = var.ami_id
  instance_type      = var.instance_type
  subnet_id          = module.vpc.public_subnet_ids[0]
  security_group_ids = [module.security.web_sg_id]
  key_name           = aws_key_pair.deployer.key_name
  environment        = "assignment3-web"
  is_public          = true
  user_data          = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y nginx
    systemctl start nginx
    systemctl enable nginx
    INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
    echo "<html><body><h1>Web Server</h1><p>Instance ID: $INSTANCE_ID</p></body></html>" > /usr/share/nginx/html/index.html
  EOF
}

# DB Server EC2 (Task 2)
module "db_server" {
  source             = "./modules/compute"
  ami_id             = var.ami_id
  instance_type      = var.instance_type
  subnet_id          = module.vpc.private_subnet_ids[0]
  security_group_ids = [module.security.db_sg_id]
  key_name           = aws_key_pair.deployer.key_name
  environment        = "assignment3-db"
  is_public          = false
}

# Task 3: S3 Bucket
# IMPORTANT: Replace "your-roll-number" with your actual roll number. Must be lowercase.
# resource "aws_s3_bucket" "terraform_state" {
#   bucket        = "assignment3-tfstate-13b3b0cc"
#   force_destroy = true
#   tags          = { Name = "assignment3-terraform-state" }
# }

# resource "aws_s3_bucket_versioning" "state" {
#   bucket = aws_s3_bucket.terraform_state.id
#   versioning_configuration { status = "Enabled" }
# }

# resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
#   bucket = aws_s3_bucket.terraform_state.id
#   rule {
#     apply_server_side_encryption_by_default {
#       sse_algorithm = "AES256"
#     }
#   }
# }

# resource "aws_s3_bucket_public_access_block" "state" {
#   bucket                  = aws_s3_bucket.terraform_state.id
#   block_public_acls       = true
#   block_public_policy     = true
#   ignore_public_acls      = true
#   restrict_public_buckets = true
# }

# resource "aws_dynamodb_table" "tf_lock" {
#   name         = "assignment3-tf-lock"
#   billing_mode = "PAY_PER_REQUEST"
#   hash_key     = "LockID"
#   attribute {
#     name = "LockID"
#     type = "S"
#   }
#   tags = { Name = "assignment3-tf-lock" }
# }

# IAM role for EC2 → S3
# resource "aws_iam_role" "ec2_s3_role" {
#   name = "assignment3-ec2-s3-role"
#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [{
#       Action    = "sts:AssumeRole"
#       Effect    = "Allow"
#       Principal = { Service = "ec2.amazonaws.com" }
#     }]
#   })
# }

# resource "aws_iam_role_policy" "s3_rw" {
#   name = "assignment3-s3-rw"
#   role = aws_iam_role.ec2_s3_role.id
#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [{
#       Effect   = "Allow"
#       Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
#       Resource = [
#         aws_s3_bucket.terraform_state.arn,
#         "${aws_s3_bucket.terraform_state.arn}/*"
#       ]
#     }]
#   })
# }

# Task 4 & 7: Launch Template + Blue/Green ASG
resource "aws_launch_template" "web" {
  name          = "assignment3-lt"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = aws_key_pair.deployer.key_name

  vpc_security_group_ids = [module.security.web_sg_id]

  # IAM profile to allow pulling from ECR
  iam_instance_profile {
    name = module.jenkins.agent_instance_profile_name
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    yum update -y
    yum install -y docker
    systemctl start docker
    systemctl enable docker
    # AWS configuration and pull image will be dynamically injected by pipeline
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = { Name = "assignment3-asg-instance" }
  }
}

resource "aws_autoscaling_group" "blue" {
  name                = "assignment3-asg-blue"
  min_size            = 1
  max_size            = 3
  desired_capacity    = 1
  vpc_zone_identifier = module.vpc.public_subnet_ids

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.blue.arn]
  
  tag {
    key                 = "Name"
    value               = "assignment3-asg-blue"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_group" "green" {
  name                = "assignment3-asg-green"
  min_size            = 1
  max_size            = 3
  desired_capacity    = 1
  vpc_zone_identifier = module.vpc.public_subnet_ids

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.green.arn]

  tag {
    key                 = "Name"
    value               = "assignment3-asg-green"
    propagate_at_launch = true
  }
}

# Task 5: Application Load Balancer (Blue-Green)
resource "aws_lb" "web" {
  name               = "assignment3-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [module.security.alb_sg_id]
  subnets            = module.vpc.public_subnet_ids
  tags               = { Name = "assignment3-alb" }
}

resource "aws_lb_target_group" "blue" {
  name     = "assignment3-tg-blue"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id

  health_check {
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
  }
}

resource "aws_lb_target_group" "green" {
  name     = "assignment3-tg-green"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id

  health_check {
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
  }
}

resource "aws_lb_listener" "web" {
  load_balancer_arn = aws_lb.web.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.blue.arn
  }
  
  lifecycle {
    ignore_changes = [default_action]
  }
}

resource "aws_lb_listener" "test" {
  load_balancer_arn = aws_lb.web.arn
  port              = 8080
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.green.arn
  }
  
  lifecycle {
    ignore_changes = [default_action]
  }
}

# Task 1: Jenkins Controller and Agent
module "jenkins" {
  source            = "./jenkins"
  vpc_id            = module.vpc.vpc_id
  public_subnet_id  = module.vpc.public_subnet_ids[0]
  private_subnet_id = module.vpc.private_subnet_ids[0]
  my_ip             = "${chomp(data.http.my_ip.response_body)}/32"
  ami_id            = var.ami_id
  instance_type     = var.instance_type
  key_name          = aws_key_pair.deployer.key_name
}