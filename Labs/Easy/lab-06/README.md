# Lab 06

## Scenario

A web server has been deployed in a custom VPC using Terraform. The VPC has an internet gateway attached, the subnet's route table sends `0.0.0.0/0` to it, a network ACL has been added to the subnet, and the security group allows HTTP in and all traffic out.

Everything seems okay, turns out it's not

Run `terraform apply`, give the instance a couple of minutes to boot, then try loading the URL from the `web_url` output in your browser.

> **Note:** Make sure you load the URL over `http://`, not `https://`. This lab only deals with plain HTTP; some browsers will auto-upgrade a typed-in address to `https://`, which will not work here regardless of the actual issue.

## Task

The page does not load. Find out why and fix it, and make sure the page actually loads once you're done, not just that the error goes away.

## Getting started

Move into the lab folder:

```bash
cd Labs/Intermediate/lab-06
```

Initialize Terraform (downloads the providers this config needs):

```bash
terraform init
```

Preview the changes Terraform is about to make:

```bash
terraform plan
```

Apply the configuration and deploy the infrastructure:

```bash
terraform apply
```

## Cleanup

Once done remember to tear down all the resources this lab created to avoid unnecessary costs:

```bash
terraform destroy
```
