output "instance_public_ip" {
  description = "Public IP of the web instance"
  value       = aws_instance.web.public_ip
}

output "instance_public_dns" {
  description = "Public DNS name of the web instance"
  value       = aws_instance.web.public_dns
}

output "web_url" {
  description = "URL to test in the browser"
  value       = "http://${aws_instance.web.public_dns}"
}