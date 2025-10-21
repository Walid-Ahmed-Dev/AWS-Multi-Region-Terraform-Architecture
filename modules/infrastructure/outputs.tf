################################################################################
# Security Groups
################################################################################
output "security_group-servers" {
  description = "The ID of the servers security group"
  value       = aws_security_group.servers.id
}
output "security_group-lb" {
  description = "The ID of the load balancer security group"
  value       = aws_security_group.lb.id
}
################################################################################
# Key
################################################################################
output "private_key" {
  description = "The private key in PEM format"
  value       = tls_private_key.key.private_key_pem
  sensitive   = true
}

output "public_key" {
  description = "The public key in OpenSSH format"
  value       = data.tls_public_key.key.public_key_openssh
}
################################################################################
# ami for Launch Template and Syslog server 
################################################################################
output "ami_id" {
  description = "The local AMI"
  value = data.aws_ami.latest_amazon_linux_image.id
}
################################################################################
# DNS
################################################################################
output "ALB-DNS" { # dns name
  description = "ALB DNS"
  value     =  aws_lb.app1_alb.dns_name
}
