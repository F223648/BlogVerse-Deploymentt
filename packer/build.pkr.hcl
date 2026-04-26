packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.0"
      source  = "github.com/hashicorp/amazon"
    },
   
  }
}

variable "region" {
  default = "us-east-1"
}

source "amazon-ebs" "ubuntu" {
  ami_name      = "assignment3-custom-ami-{{timestamp}}"
  instance_type = "t3.micro"
  region        = var.region

  source_ami_filter {
    filters = {
      name                = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["099720109477"]  # Canonical
  }

  ssh_username = "ubuntu"
}

build {
  sources = ["source.amazon-ebs.ubuntu"]

  provisioner "shell" {
    inline = [
      "sudo apt-get update -y",
      "sudo apt-get install -y nginx curl",
      "sudo systemctl enable nginx",
      "echo '<html><body><h1>Welcome — Custom Packer AMI</h1></body></html>' | sudo tee /var/www/html/index.html"
    ]
  }
}