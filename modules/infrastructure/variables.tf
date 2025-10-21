################################################################################
# Providers
################################################################################
variable "region" {
  description = "region value"
  type        = string
}
################################################################################
# VPC
################################################################################
variable "vpc_id" {
  description = "The ID of the VPC"
  type        = string
}
################################################################################
# Tags
################################################################################
variable "name" {
  description = "Name tag value"
  type        = string
}

variable "service" {
  description = "Service tag value"
  type        = string
}
################################################################################
# Launch Template
################################################################################
variable "syslog_ip" {
  description = "The IP address of the syslog server"
  type        = string
}
################################################################################
# Key
################################################################################
variable "key_name" {
  description = "The name of the key pair"
  type        = string
}
################################################################################
# Subnets
################################################################################
variable "subnet1" {
  description = "The subnet1 of the VPC"
  type        = string
}
variable "subnet2" {
  description = "The subnet2 of the VPC"
  type        = string
}
variable "subnet3" {
  description = "The subnet3 of the VPC"
  type        = string
}
variable "subnet4" {
  description = "The subnet4 of the VPC"
  type        = string
}

