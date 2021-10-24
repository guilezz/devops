# we provision resources only in aws region which is defined by the variable
provider "aws" {
  region = "eu-west-1"
}

# Create a new VPC using the 10.0.0.0/16 CIDR block
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = "main"
  }
}

# Create a new subnet for the created VPC
resource "aws_subnet" "main" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "main"
  }
}

# Create a new internet gateway for the VPC
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "main"
  }
}

# Manage the default route table of the VPC and
# add a route for 0.0.0.0/0 that sends traffic
# to the managed internet gateway.
resource "aws_default_route_table" "main" {
  default_route_table_id = aws_vpc.main.default_route_table_id
  tags = {
    "Name" = "main"
  }
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}

# Create a new security group that allows inbound http requests
resource "aws_security_group" "allow_inbound_http" {
  name        = "allow-inbound-http"
  description = "Allow inbound HTTP traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create a new security group that allows outbound traffic
resource "aws_security_group" "allow_outbound_traffic" {
  name        = "allow-outbound-traffic"
  description = "Allow all outbound traffic"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Define an output value of the IP of the EC2 instance
output "aws-webapp-ip" {
  value = aws_instance.web_server_01.public_ip
}

# Create a new instance of the latest Ubuntu 14.04 on an
# t2.micro node with an AWS Tag naming it "web-server-01"
resource "aws_instance" "web_server_01" {
  ami           = "ami-09e67e426f25ce0d7"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.main.id
  user_data     = <<EOT
#!/bin/bash

sudo apt-get update -y
sudo apt-get install -y curl docker.io git
sudo mkdir -p /etc/systemd/system/docker.service.d
sudo tee /etc/docker/daemon.json <<EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF

sudo systemctl daemon-reload 
sudo systemctl restart docker
sudo systemctl enable docker

sudo curl -L "https://github.com/docker/compose/releases/download/1.25.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
sudo ln -s /usr/local/bin/docker-compose /usr/bin/dc
sudo apt -y install bash-completion
sudo curl https://raw.githubusercontent.com/docker/docker-ce/master/components/cli/contrib/completion/bash/docker -o /etc/bash_completion.d/docker.sh
sudo groupadd docker
sudo usermod -aG docker $USER
git clone https://github.com/guilezz/devops.git
cd devops
sudo docker build -t calibrate:latest .
sudo docker-compose up -d


EOT

  tags = {
    Name = "web-server-01"
  }

  vpc_security_group_ids = [
    aws_security_group.allow_inbound_http.id,
    aws_security_group.allow_outbound_traffic.id,
  ]
}


