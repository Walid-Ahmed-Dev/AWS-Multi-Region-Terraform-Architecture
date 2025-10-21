################################################################################
# VPC
################################################################################
output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.vpc.id #used as a reference and input for the aws_vpc.vpc object 
}
################################################################################
# Subnets
################################################################################
output "subnet1_id" {
  description = "The ID of subnet 1"
  value       = aws_subnet.subnet1.id
}

output "subnet2_id" {
  description = "The ID of subnet 2"
  value       = aws_subnet.subnet2.id
}

output "subnet3_id" {
  description = "The ID of subnet 3"
  value       = aws_subnet.subnet3.id
}

output "subnet4_id" {
  description = "The ID of subnet 4"
  value       = aws_subnet.subnet4.id
}
