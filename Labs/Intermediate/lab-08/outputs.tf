output "instance_id" {
  description = "ID of the web instance"
  value       = aws_instance.web.id
}

output "instance_public_ip" {
  description = "Public IP of the web instance"
  value       = aws_instance.web.public_ip
}

output "web_url" {
  description = "URL to test in the browser"
  value       = "http://${aws_instance.web.public_dns}"
}
