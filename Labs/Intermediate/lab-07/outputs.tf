output "instance_id" {
  description = "ID of the private web instance"
  value       = aws_instance.web.id
}

output "instance_private_ip" {
  description = "Private IP of the web instance"
  value       = aws_instance.web.private_ip
}

output "web_url" {
  description = "URL to test in the browser"
  value       = "http://${aws_lb.web.dns_name}"
}
