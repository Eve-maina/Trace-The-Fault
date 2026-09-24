output "instance_id" {
  description = "ID of the private app instance"
  value       = aws_instance.app.id
}

output "instance_private_ip" {
  description = "Private IP of the app instance"
  value       = aws_instance.app.private_ip
}

output "nat_gateway_public_ip" {
  description = "Public IP of the NAT gateway"
  value       = aws_eip.nat.public_ip
}

output "ssm_connect_command" {
  description = "Command to open a shell on the instance through Session Manager"
  value       = "aws ssm start-session --target ${aws_instance.app.id} --region ${var.aws_region}"
}
