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
    Name = "trace-the-fault-lab-04"
  }
}

#Internet Gateway
resource "aws_internet_gateway" "myigw" {
  vpc_id = aws_vpc.myvpc.id

  tags = {
    Name = "trace-the-fault-lab-04-igw"
  }
}

#Public Subnet 
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true

  tags = {
    Name = "trace-the-fault-lab-04-public-subnet"
  }
}

#Private Subnet
resource "aws_subnet" "private" {
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = var.private_subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = false

  tags = {
    Name = "trace-the-fault-lab-04-private-subnet"
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
    Name = "trace-the-fault-lab-04-public-route-table"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

#Elastic IP for the NAT gateway
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "trace-the-fault-lab-04-nat-eip"
  }
}

#NAT Gateway
resource "aws_nat_gateway" "mynat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id

  tags = {
    Name = "trace-the-fault-lab-04-nat"
  }

  depends_on = [aws_internet_gateway.myigw]
}

#Private route table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.myvpc.id


  tags = {
    Name = "trace-the-fault-lab-04-private-route-table"
  }
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

#Security Group
resource "aws_security_group" "app" {
  name        = "trace-the-fault-lab-04-sg"
  description = "Security group of the private app instance"
  vpc_id      = aws_vpc.myvpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "trace-the-fault-lab-04-sg"
  }
}

#IAM role so the instance can be managed through SSM Session Manager
resource "aws_iam_role" "ssm" {
  name = "trace-the-fault-lab-04-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm" {
  name = "trace-the-fault-lab-04-ssm-profile"
  role = aws_iam_role.ssm.name
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
resource "aws_instance" "app" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.app.id]
  iam_instance_profile   = aws_iam_instance_profile.ssm.name

  tags = {
    Name = "trace-the-fault-lab-04-app"
  }
}
