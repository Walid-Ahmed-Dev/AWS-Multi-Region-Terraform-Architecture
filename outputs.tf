# Output the VPC ID from the vpc child module
output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc_japan.vpc_id
}

# Output the Subnet IDs from the vpc child module
output "subnet1_id" {
  description = "The ID of subnet 1"
  value       = module.vpc_japan.subnet1_id
}

output "subnet2_id" {
  description = "The ID of subnet 2"
  value       = module.vpc_japan.subnet2_id
}

output "subnet3_id" {
  description = "The ID of subnet 3"
  value       = module.vpc_japan.subnet3_id
}

output "subnet4_id" {
  description = "The ID of subnet 4"
  value       = module.vpc_japan.subnet4_id
}

# Output the Security group IDs from the infrastructure child module
output "security_group-servers" {
  description = "The ID of the servers security group"
  value       = module.infrastructure_japan.security_group-servers
}

output "security_group-lb" {
  description = "The ID of the load balancer security group"
  value       = module.infrastructure_japan.security_group-lb
}


# Output the ALB DNS from the infrastructure child module
output "ALB-DNS" {
  description = "The ID of the ALB DNS"
  value = module.infrastructure_japan.ALB-DNS
}
output "ALB-DNS-NewYork" {
  description = "The ID of the ALB DNS"
  value = module.infrastructure_NewYork.ALB-DNS
}

# Output the private key from the infrastructure child module
output "private_key-japan" { #bash "terraform output private_key-japan"  to print to standard output
  description = "The private key in PEM format"
  value       = module.infrastructure_japan.private_key
  sensitive   = true
}
output "private_key-NewYork" {
  description = "The private key in PEM format"
  value       = module.infrastructure_NewYork.private_key
  sensitive   = true
}