################################################################################
# Providers
################################################################################
variable "region" {
  description = "region value"
}
################################################################################
# VPC
################################################################################
variable "cidr_block" {
  description = "CIDR block value" 
  type = string
}
################################################################################
# Tags
################################################################################
variable "name" {
  description = "Name tag value" 
  type = string
}
variable "service" {
  description = "Service tag value" 
  type = string
}
################################################################################
# Subnets
################################################################################
variable "subnet1_cidr_block" {
  description = "CIDR block for subnet 1"
  type = string
}
variable "subnet2_cidr_block" {
  description = "CIDR block for subnet 2"
  type = string
}
variable "subnet3_cidr_block" {
  description = "CIDR block for subnet 3"
  type = string
}
variable "subnet4_cidr_block" {
  description = "CIDR block for subnet 4"
  type = string
}
variable "AZ1" {
  description = "Availability Zone for subnet 1"
  type = string
}
variable "AZ2" {
  description = "Availability Zone for subnet 2"
  type = string
}
################################################################################
# TGW_id
################################################################################
variable "TGW_id" {
  description = "TGW id"
  type        = string
}
