terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">=5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

#VPC
resource "aws_vpc" "myvpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "trace-the-fault-lab-07"
  }
}

#Internet Gateway
resource "aws_internet_gateway" "myigw" {
  vpc_id = aws_vpc.myvpc.id

  tags = {
    Name = "trace-the-fault-lab-07-igw"
  }
}

#Public Subnets (the load balancer needs two availability zones)
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = var.public_subnet_a_cidr
  availability_zone       = var.availability_zone_a
  map_public_ip_on_launch = true

  tags = {
    Name = "trace-the-fault-lab-07-public-subnet-a"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = var.public_subnet_b_cidr
  availability_zone       = var.availability_zone_b
  map_public_ip_on_launch = true

  tags = {
    Name = "trace-the-fault-lab-07-public-subnet-b"
  }
}

#Private Subnet
resource "aws_subnet" "private" {
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = var.private_subnet_cidr
  availability_zone       = var.availability_zone_a
  map_public_ip_on_launch = false

  tags = {
    Name = "trace-the-fault-lab-07-private-subnet"
  }
}

#Public route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.myigw.id
  }

  tags = {
    Name = "trace-the-fault-lab-07-public-route-table"
  }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

#Elastic IP for the NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "trace-the-fault-lab-07-nat-eip"
  }
}

#NAT Gateway
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_a.id

  tags = {
    Name = "trace-the-fault-lab-07-nat"
  }

  depends_on = [aws_internet_gateway.myigw]
}

#Private route table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "trace-the-fault-lab-07-private-route-table"
  }
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

#Security Group for the load balancer
resource "aws_security_group" "alb" {
  name        = "trace-the-fault-lab-07-alb-sg"
  description = "Security group of the load balancer"
  vpc_id      = aws_vpc.myvpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "trace-the-fault-lab-07-alb-sg"
  }
}

#Security Group for the web instance
resource "aws_security_group" "web" {
  name        = "trace-the-fault-lab-07-web-sg"
  description = "Security group of the private web instance"
  vpc_id      = aws_vpc.myvpc.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "trace-the-fault-lab-07-web-sg"
  }
}

#AMI lookup
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

#EC2 Instance
resource "aws_instance" "web" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.web.id]

  user_data = <<-EOF
              #!/bin/bash
              until dnf install -y --setopt=timeout=10 --setopt=retries=1 httpd; do
                sleep 15
              done
              systemctl start httpd
              systemctl enable httpd
              cat <<'HTML' > /var/www/html/index.html
              <!DOCTYPE html>
              <html lang="en">
              <head>
                <meta charset="UTF-8">
                <title>Lab 07</title>
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

  depends_on = [aws_route_table_association.private]

  tags = {
    Name = "trace-the-fault-lab-07-web"
  }
}

#Application Load Balancer
resource "aws_lb" "web" {
  name               = "trace-the-fault-lab-07-alb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]

  tags = {
    Name = "trace-the-fault-lab-07-alb"
  }
}

resource "aws_lb_target_group" "web" {
  name     = "trace-the-fault-lab-07-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.myvpc.id

  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 15
  }

  tags = {
    Name = "trace-the-fault-lab-07-tg"
  }
}

resource "aws_lb_target_group_attachment" "web" {
  target_group_arn = aws_lb_target_group.web.arn
  target_id        = aws_instance.web.id
  port             = 80
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.web.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}
