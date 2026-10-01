# Lab 07

## Scenario

A web server has been deployed into the private subnet of a custom VPC using Terraform. It has no public IP on purpose. Visitors reach it through an Application Load Balancer that sits in two public subnets, and the instance installs its web server from the internet when it first boots.

The VPC has an internet gateway, the public subnets route to it, there is a NAT gateway with an Elastic IP, and the private subnet's route table sends `0.0.0.0/0` to that NAT gateway. The load balancer's security group allows HTTP from anywhere, and the instance's security group allows HTTP from the load balancer and all traffic out.

Everything seems okay, turns out it's not

Run `terraform apply`, give the instance a few minutes to boot, then try loading the URL from the `web_url` output in your browser.

> **Note:** Make sure you load the URL over `http://`, not `https://`. This lab only deals with plain HTTP; some browsers will auto-upgrade a typed-in address to `https://`, which will not work here regardless of the actual issue.

## Task

The page does not load. Find out why and fix it, and make sure the page actually loads once you're done, not just that the error goes away.

## Getting started

Move into the lab folder:

```bash
cd Labs/Intermediate/lab-07
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

Once done remember to tear down all the resources this lab created to avoid unnecessary costs. The NAT gateway and the load balancer are billed by the hour whether or not you use them:

```bash
terraform destroy
```
