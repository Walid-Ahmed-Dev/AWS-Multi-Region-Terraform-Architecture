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
# TGW
################################################################################
resource "aws_ec2_transit_gateway" "TGW1" {
  provider = aws
  tags = {
    Name: "${var.name_TGW_Region}-TGW1"
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "Private-VPC-MainRegion-TG-attach" {
  subnet_ids         = [var.subnet3_id, var.subnet4_id]
  transit_gateway_id = aws_ec2_transit_gateway.TGW1.id
  vpc_id             = var.vpc_id
  transit_gateway_default_route_table_association = false #or  by default associate to default TGW-Route-table
  transit_gateway_default_route_table_propagation = false #or  by default propagate to default TGW-Route-table
}


resource "aws_ec2_transit_gateway_route_table" "TG-Route-Table" { #TGW route table  
  transit_gateway_id = aws_ec2_transit_gateway.TGW1.id 
}

resource "aws_ec2_transit_gateway_route_table_association" "TGW1_Association" { #Associates MainRegion-VPC-TGW-attach to TGW-Route-Table
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.Private-VPC-MainRegion-TG-attach.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.TG-Route-Table.id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "TGW1_Propagation" { #Propagates MainRegion-VPC-TGW-attach to TGW-Route-Table
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.Private-VPC-MainRegion-TG-attach.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.TG-Route-Table.id
}
