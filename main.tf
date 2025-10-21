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
  region = "ap-northeast-1"
}
provider "aws" {
  alias = "us-east-1"
  region = "us-east-1" 
}
################################################################################
# Modules and Infrastructure
################################################################################
# vpc
module "vpc_japan" {
  source             = "./modules/vpc"
  region             = "ap-northeast-1"
  cidr_block         = "10.150.0.0/16"
  name               = "app1"
  service            = "J-Tele-Doctor"
  subnet1_cidr_block = "10.150.1.0/24"
  subnet2_cidr_block = "10.150.3.0/24"
  subnet3_cidr_block = "10.150.11.0/24"
  subnet4_cidr_block = "10.150.13.0/24"
  AZ1                = "ap-northeast-1a"
  AZ2                = "ap-northeast-1c"
  TGW_id             = module.TGW_japan.TGW_id
}
resource "aws_subnet" "private-ap-northeast-1c-2" {
  vpc_id                  = module.vpc_japan.vpc_id
  cidr_block              = "10.150.23.0/24"
  availability_zone       = "ap-northeast-1c"
  map_public_ip_on_launch = false

  tags = {
    Name    = "app1-private-subnet1"
    Service = "J-Tele-Doctor"
  }
}
resource "aws_subnet" "private-ap-northeast-1d" {
  vpc_id                  = module.vpc_japan.vpc_id
  cidr_block              = "10.150.14.0/24"
  availability_zone       = "ap-northeast-1d"
  map_public_ip_on_launch = false

  tags = {
    Name    = "app1-private-subnet1"
    Service = "J-Tele-Doctor"
  }
}
# infrastructure
module "infrastructure_japan" {
  source             = "./modules/infrastructure"
  region             = "ap-northeast-1"
  vpc_id             = module.vpc_japan.vpc_id
  name               = "app1"
  service            = "J-Tele-Doctor"
  key_name           = "key"
  subnet1            = module.vpc_japan.subnet1_id
  subnet2            = module.vpc_japan.subnet2_id
  subnet3            = module.vpc_japan.subnet3_id 
  subnet4            = module.vpc_japan.subnet4_id
  syslog_ip          = aws_instance.syslog-server.private_ip
  dependency_trigger = aws_route53_record.syslog.id
}
resource "aws_security_group" "Aurora-japan" {
  name        = "Aurora-sg"
  description = "Aurora-sg"
  vpc_id      = module.vpc_japan.vpc_id

  ingress {
    description     = "Allow Aurora traffic from application tier"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [module.infrastructure_japan.security_group-servers]
  }

  ingress {
    description     = "Allow Aurora traffic from syslog servers"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ssh_syslog-japan.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "Aurora-sg"
    Service = "J-Tele-Doctor"
  }
}
resource "aws_security_group" "ssh_syslog-japan" {
  name        = "app1-ssh-syslog"
  description = "app1-ssh-syslog"
  vpc_id      = module.vpc_japan.vpc_id

  ingress { 
    description = "Allow SSH traffic"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow syslog traffic (UDP)"
    from_port   = 514
    to_port     = 514
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow syslog traffic (TCP)"
    from_port   = 514
    to_port     = 514
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # any protocol
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "app1-ssh-syslog"
  }
}
resource "aws_security_group" "Endpoint-Japan" {
  name        = "app1-endpoint-sg"
  description = "Endpoint security group allowing SSH traffic"
  vpc_id      = module.vpc_japan.vpc_id


  ingress {
    description = "Allow SSH traffic"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # Allow all outbound traffic
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "app1-endpoint-sg"
    Service = "J-Tele-Doctor"
  }
}
# TGW
module "TGW_japan" {
  source          = "./modules/TGW"
  region          = "ap-northeast-1"
  vpc_id          = module.vpc_japan.vpc_id
  name_TGW_Region = "Japan"
  subnet3_id      = module.vpc_japan.subnet3_id
  subnet4_id      = module.vpc_japan.subnet4_id
}

# NewYork
module "vpc_NewYork" {
  source             = "./modules/vpc"
  region             = "us-east-1"
  cidr_block         = "10.151.0.0/16"
  name               = "app1"
  service            = "J-Tele-Doctor"
  subnet1_cidr_block = "10.151.1.0/24"
  subnet2_cidr_block = "10.151.2.0/24"
  subnet3_cidr_block = "10.151.11.0/24"
  subnet4_cidr_block = "10.151.12.0/24"
  AZ1                = "us-east-1a"
  AZ2                = "us-east-1b"
  TGW_id             = module.TGW_NewYork.TGW_id
}
module "infrastructure_NewYork" {
  source                    = "./modules/infrastructure"
  region                    =  "us-east-1"
  vpc_id                    = module.vpc_NewYork.vpc_id
  name                      = "app1"
  service                   = "J-Tele-Doctor"
  key_name                  = "key"
  subnet1                   = module.vpc_NewYork.subnet1_id
  subnet2                   = module.vpc_NewYork.subnet2_id
  subnet3                   = module.vpc_NewYork.subnet3_id 
  subnet4                   = module.vpc_NewYork.subnet4_id
  syslog_ip                 = aws_instance.syslog-server.private_ip
  dependency_trigger        = aws_route53_record.syslog.id
}
module "TGW_NewYork" {
  source          = "./modules/TGW"
  region          = "us-east-1"
  vpc_id          = module.vpc_NewYork.vpc_id
  name_TGW_Region = "NewYork"
  subnet3_id      = module.vpc_NewYork.subnet3_id
  subnet4_id      = module.vpc_NewYork.subnet4_id
}
################################################################################
# TGW Peer Requestor
################################################################################
resource "aws_ec2_transit_gateway_peering_attachment" "Japan_NewYork_Peer_Request" { #peer
  transit_gateway_id        = module.TGW_japan.TGW_id
  peer_transit_gateway_id   = module.TGW_NewYork.TGW_id
  peer_region               = "us-east-1"
  tags = {
    Name = "Japan-NewYork-Peer-Request"
  }
}
################################################################################
# TGW Peer Acceptor
################################################################################
resource "aws_ec2_transit_gateway_peering_attachment_accepter" "NewYork_Japan_Peer_Accepter" { #accept peer
  provider                      = aws.us-east-1
  transit_gateway_attachment_id = aws_ec2_transit_gateway_peering_attachment.Japan_NewYork_Peer_Request.id
  tags = {
    Name = "NewYork-Japan-Peer-Accepter"
  }
}
################################################################################
# Associate TGW Peers to TGW Route-table 
################################################################################
#Japan
resource "aws_ec2_transit_gateway_route_table_association" "Japan-TGW1_Peer_Association" { #Associates Japan-NewYork-TGW-Peer to Japan-TGW-Route-Table
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment_accepter.NewYork_Japan_Peer_Accepter.id #ensures the peer is accepted before association
  transit_gateway_route_table_id = module.TGW_japan.TGW_route_table_id
  replace_existing_association   = true #removes default TGW-Route-Table-Association so you can associate with the TGW-Route-Table specified in your code
}
#NewYork
resource "aws_ec2_transit_gateway_route_table_association" "NewYork-TGW1_Peer_Association" { #Associates Japan-NewYork-TGW-Peer to Japan-TGW-Route-Table
  provider = aws.us-east-1
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment_accepter.NewYork_Japan_Peer_Accepter.id #ensures the peer is accepted before association
  transit_gateway_route_table_id = module.TGW_NewYork.TGW_route_table_id
  replace_existing_association   = true #removes default TGW-Route-Table-Association so you can associate with the TGW-Route-Table specified in your code
}
################################################################################
# Define route between TGW Peers inside the TGW Route-table 
################################################################################
#Japan
resource "aws_ec2_transit_gateway_route" "Japan_to_NewYork_Route" { #Route on TGW Japan -> to -> NewYork
  transit_gateway_route_table_id = module.TGW_japan.TGW_route_table_id
  destination_cidr_block         = "10.151.0.0/16"  # CIDR block of the VPC in us-east-1
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment_accepter.NewYork_Japan_Peer_Accepter.id #ensures the peer is accepted before defining route
}
#NewYork
resource "aws_ec2_transit_gateway_route" "NewYork_to_Japan_Route" { #Route on TGW NewYork -> to -> Japan
  provider = aws.us-east-1
  transit_gateway_route_table_id = module.TGW_NewYork.TGW_route_table_id
  destination_cidr_block         = "10.150.0.0/16"  # CIDR block of the VPC in ap-northeast-1
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment_accepter.NewYork_Japan_Peer_Accepter.id #ensures the peer is accepted before defining route
}
################################################################################
# Syslog server and its' associated Endpoint
################################################################################
resource "aws_ec2_instance_connect_endpoint" "Japan_Endpoint" {
  subnet_id          = module.vpc_japan.subnet1_id
  security_group_ids = [aws_security_group.Endpoint-Japan.id]
}

resource "aws_instance" "syslog-server" { #SYSLOG server in private Zone. Logs Agents TCP/UDP port 514 traffic. View traffic via "tail -f /var/log/messages"
  ami                     = module.infrastructure_japan.ami_id
  instance_type           = "t3.micro"
  subnet_id               = module.vpc_japan.subnet3_id
  vpc_security_group_ids  = [aws_security_group.ssh_syslog-japan.id]
  user_data = base64encode(<<-EOF
#!/bin/bash
# Install and configure rsyslog
# Install rsyslog
yum install -y rsyslog

# Start and enable rsyslog
systemctl start rsyslog
systemctl enable rsyslog

# Configure rsyslog to accept remote logs
echo "
# Provides TCP syslog reception
module(load=\"imtcp\")
input(type=\"imtcp\" port=\"514\")

# Provides UDP syslog reception
module(load=\"imudp\")
input(type=\"imudp\" port=\"514\")
" >> /etc/rsyslog.conf

# Restart rsyslog to apply changes
systemctl restart rsyslog

 EOF
  )
user_data_replace_on_change = true
lifecycle { #new instances are created before the old ones are destroyed. This helps maintain continuity without causing a temporary downtime.
  create_before_destroy = true 
  }
tags = {
  Name = "syslog-server"
  }

}

resource "aws_instance" "syslog-server2" { #SYSLOG server in private Zone. Logs Agents TCP/UDP port 514 traffic. View traffic via "tail -f /var/log/messages"
  ami                     = module.infrastructure_japan.ami_id
  instance_type           = "t3.micro"
  subnet_id               = module.vpc_japan.subnet4_id
  vpc_security_group_ids  = [aws_security_group.ssh_syslog-japan.id]
  user_data = base64encode(<<-EOF
#!/bin/bash
# Install and configure rsyslog
# Install rsyslog
yum install -y rsyslog

# Start and enable rsyslog
systemctl start rsyslog
systemctl enable rsyslog

# Configure rsyslog to accept remote logs
echo "
# Provides TCP syslog reception
module(load=\"imtcp\")
input(type=\"imtcp\" port=\"514\")

# Provides UDP syslog reception
module(load=\"imudp\")
input(type=\"imudp\" port=\"514\")
" >> /etc/rsyslog.conf

# Restart rsyslog to apply changes
systemctl restart rsyslog

 EOF
  )
user_data_replace_on_change = true
lifecycle { #new instances are created before the old ones are destroyed. This helps maintain continuity without causing a temporary downtime.
  create_before_destroy = true 
  }
tags = {
  Name = "syslog-server2"
  }

}





