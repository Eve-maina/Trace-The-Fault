# Lab 02

## Scenario

A web server has been deployed in a custom VPC using Terraform. The instance is running, the VPC has an internet gateway attached and the subnet is configured for public IP assignment.

Everything seems okay, turns out it's not

Run `terraform apply`, then try loading the URL from the `web_url` output in your browser.

> **Note:** Make sure you load the URL over `http://`, not `https://`. This lab only deals with plain HTTP; some browsers will auto-upgrade a typed-in address to `https://`, which will not work here regardless of the actual issue.

## Task

The page does not load. Find out why and fix it.

## Getting started

Move into the lab folder:

```bash
cd Labs/Easy/Lab-02
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
