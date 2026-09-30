# Lab 05

## Scenario

A new application server has been deployed into the private subnet of a custom VPC using Terraform. It has no public IP on purpose, nobody should be able to reach it from the internet. The team manages it through AWS Systems Manager Session Manager instead of SSH, and it needs outbound internet access to pull updates and packages.

The VPC has an internet gateway, the public subnet routes to it, the instance has an IAM role with the Session Manager policy attached, and the security group allows all outbound traffic. The private subnet also has its own route table associated with it.

Everything seems okay, turns out it's not

Run `terraform apply`, wait a few minutes for the instance to boot, then try to connect to it through Session Manager, either with the **Connect** button in the EC2 console (**Session Manager** tab) or with the `ssm_connect_command` output.

> **Note:** Connecting from your terminal needs the [Session Manager plugin](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html) for the AWS CLI. If you don't want to install it, use the EC2 console instead.

## Task

You can't connect to the instance. Find out why and fix it.

## Getting started

Move into the lab folder:

```bash
cd Labs/Easy/lab-05
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

Once done remember to tear down all the resources this lab created to avoid unnecessary costs. Some of the resources you may add while fixing this lab are billed by the hour whether or not you use them:

```bash
terraform destroy
```
