# Lab 01

## Scenario

A web server has been deployed in a custom VPC using Terraform. The instance is running, the VPC has an internet gateway attached and the subnet is configured for public IP assignment.

Everything seems okay, turns out it's not

Run `terraform apply`, then try loading the URL from the `web_url` output in your browser.

## Task

The page does not load. Find out why and fix it.

## Getting started

```bash
terraform init
terraform plan
terraform apply
```

## Cleanup

```bash
terraform destroy
```
