terraform {
  required_providers {
    aws = {
        source = "hashicorp/aws"
        version = ">=5.0"
    }
  }
}

provider "aws" {
    region = var.aws_region 
  
}

#VPC
resource "aws_vpc" "myvpc" {
    cidr_block = var.vpc_cidr
    enable_dns_hostnames = true
    enable_dns_support = true

    tags = {
      Name = "trace-the-fault-lab-03"
    }
}

#Internet Gateway
resource "aws_internet_gateway" "myigw" {
  vpc_id = aws_vpc.myvpc.id
    tags = {
      Name = "trace-the-fault-lab-03-igw"
    } 
}

#Public Subnet
resource "aws_subnet" "public" {
    vpc_id = aws_vpc.myvpc.id
    cidr_block = var.public_subnet_cidr
    availability_zone = var.availability_zone
    map_public_ip_on_launch = true

    tags = {
      Name= "trace-the-fault-lab-03-public-subnet"
    }
}

#Route table
resource "aws_route_table" "mypublicrt" {
    vpc_id = aws_vpc.myvpc.id


   tags = {
     Name = "trace-the-fault-lab03-public-route-table"
  }
}

resource "aws_route_table_association" "public" {
    subnet_id = aws_subnet.public.id 
    route_table_id = aws_route_table.mypublicrt.id
}

#Security Group
resource "aws_security_group" "web" {
    name = "trace-the-fault-sg"
    description = "Security group of the web instance"
    vpc_id = aws_vpc.myvpc.id

    ingress {
      from_port = 80
      to_port = 80
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
      Name = "trace-the-fault-lab-03-sg"
    }
}

#AMI lookup
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

#EC2 Instance
resource "aws_instance" "web" {
    ami                    = data.aws_ami.amazon_linux.id
    instance_type          = var.instance_type
    subnet_id              = aws_subnet.public.id
    vpc_security_group_ids = [aws_security_group.web.id]

    user_data = <<-EOF
                #!/bin/bash
                yum install -y httpd
                systemctl start httpd
                systemctl enable httpd
                cat <<'HTML' > /var/www/html/index.html
                <!DOCTYPE html>
                <html lang="en">
                <head>
                  <meta charset="UTF-8">
                  <title>Lab 03</title>
                  <style>
                    body {
                      margin: 0;
                      height: 100vh;
                      display: flex;
                      align-items: center;
                      justify-content: center;
                      background: linear-gradient(135deg, #0f2027, #203a43, #2c5364);
                      font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
                    }
                    .card {
                      text-align: center;
                      color: #ffffff;
                      padding: 50px 70px;
                      background: rgba(255, 255, 255, 0.08);
                      border: 1px solid rgba(255, 255, 255, 0.2);
                      border-radius: 16px;
                      backdrop-filter: blur(6px);
                      box-shadow: 0 8px 32px rgba(0, 0, 0, 0.4);
                    }
                    .card h1 {
                      font-size: 2.2rem;
                      margin-bottom: 10px;
                    }
                    .card p {
                      font-size: 1.1rem;
                      color: #cfe8ff;
                    }
                    .cloud {
                      font-size: 3rem;
                      margin-bottom: 20px;
                    }
                  </style>
                </head>
                <body>
                  <div class="card">
                    <div class="cloud">☁️</div>
                    <h1>Greetings from the cloud!</h1>
                    <p>You solved the lab!</p>
                  </div>
                </body>
                </html>
                HTML
                EOF

    tags = {
      Name = "trace-the-fault-lab-03-web"
    }
}