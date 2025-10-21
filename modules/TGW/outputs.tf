output "TGW_id" {
  value       = aws_ec2_transit_gateway.TGW1.id
  description = "TGW ID"
}
output "TGW_route_table_id" {
  value       = aws_ec2_transit_gateway_route_table.TG-Route-Table.id
  description = "TGW ID"
}