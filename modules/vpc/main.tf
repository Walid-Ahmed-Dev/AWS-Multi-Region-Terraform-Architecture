################################################################################
# Version
################################################################################
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
################################################################################
# Providers
################################################################################
provider "aws" {
  region = var.region
}
################################################################################
# VPC
################################################################################
resource "aws_vpc" "vpc" {
  cidr_block = var.cidr_block
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {
    Name = "${var.name}-vpc" 
    Service = var.service
  }
}
################################################################################
# Subnets
################################################################################
resource "aws_subnet" "subnet1" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.subnet1_cidr_block
  availability_zone       = var.AZ1
  map_public_ip_on_launch = true

  tags = {
    Name    = "${var.name}-public-subnet1"
    Service = var.service
  }
}

# Create Subnet 2
resource "aws_subnet" "subnet2" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.subnet2_cidr_block
  availability_zone       = var.AZ2
  map_public_ip_on_launch = true

  tags = {
    Name    = "${var.name}-public-subnet2"
    Service = var.service
  }
}

# Create Subnet 3
resource "aws_subnet" "subnet3" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.subnet3_cidr_block
  availability_zone       = var.AZ1
  map_public_ip_on_launch = false

  tags = {
    Name    = "${var.name}-private-subnet3"
    Service = var.service
  }
}

# Create Subnet 4
resource "aws_subnet" "subnet4" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.subnet4_cidr_block
  availability_zone       = var.AZ2
  map_public_ip_on_launch = false

  tags = {
    Name    = "${var.name}-private-subnet4"
    Service = var.service
  }
}
################################################################################
# IGW
################################################################################
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name    = "${var.name}-igw"
    Service = var.service
  }
}
################################################################################
# EIP and NAT Gateway
################################################################################
resource "aws_eip" "nat" { #elastic IP
  domain = "vpc" #(Optional) Indicates if this EIP is for use in VPC

  tags = {
    Name = "${var.name}-nat"
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id 
  subnet_id     = aws_subnet.subnet1.id

  tags = {
    Name = "${var.name}-nat"
  }

  depends_on = [aws_internet_gateway.igw] # ensures terraform creates IGW before creating this resource(NGW). NGW depend on IGW
}
################################################################################
# Route Tables
################################################################################
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  route {
    cidr_block          = "10.0.0.0/8"
    transit_gateway_id  = var.TGW_id
  }

  tags = {
    Name = "${var.name}-private"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.name}-public"
  }
}
################################################################################
# Route Table Associations
################################################################################
resource "aws_route_table_association" "public1" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public2" {
  subnet_id      = aws_subnet.subnet2.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private1" {
  subnet_id      = aws_subnet.subnet3.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private2" {
  subnet_id      = aws_subnet.subnet4.id
  route_table_id = aws_route_table.private.id
}
