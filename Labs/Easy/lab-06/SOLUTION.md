# Lab 06 - Troubleshooting Hints

Try working through the problem on your own first. Expand a hint only when you're stuck.

<details>
<summary>Step 1 - Look closely at the outputs</summary>

Run:

```bash
terraform output
```

What does `web_url` actually contain? What about `instance_public_ip`?

Now open the instance in the EC2 console and check the **Public IPv4 address** and **Public IPv4 DNS** fields on the **Details** tab.

The instance has no public address, so there is nothing for the internet to reach. The real question is: why didn't it get one?

</details>

<details>
<summary>Step 2 - Where does a public IP come from?</summary>

An instance in a VPC only gets a public IPv4 address if something asks for one **at launch time**. There are two places that can ask:

1. The subnet, through its **Auto-assign public IPv4 address** setting.
2. The instance itself, through the **Auto-assign public IP** option on its network interface.

Select `trace-the-fault-lab-06-public-subnet` in the VPC console and check **Auto-assign public IPv4 address**. Then look at `aws_subnet "public"` and `aws_instance "web"` in `main.tf`. Does either of them ask for a public IP?

</details>

<details>
<summary>Step 3 - Why fixing it might not seem to work</summary>

Suppose you turn on auto-assign for the subnet and run `terraform apply`. Look at the plan carefully: what does Terraform want to change? Does the instance appear in it?

Auto-assign only applies to instances launched **after** the setting changes. And even if you attach an Elastic IP to the existing instance instead, ask yourself: when the instance first booted and ran its user data, could it reach the internet to install `httpd`?

</details>

<details>
<summary><strong>Ready for the fix? Click to reveal</strong></summary>

## What's actually wrong

The instance has no public IP address. Neither of the two settings that could give it one is turned on:

- `aws_subnet "public"` doesn't set `map_public_ip_on_launch`, which defaults to `false`.
- `aws_instance "web"` doesn't set `associate_public_ip_address`, so it falls back to whatever the subnet says.

The subnet is only "public" by name. Its route table points at the internet gateway, but the internet gateway can only translate traffic for instances that have a public IP. Without one, the instance can't be reached from the internet, and the `web_url` output ends up as just `http://`.

There's a second consequence that's easy to miss. The instance also couldn't reach the internet **outbound** when it first booted, so the `yum install -y httpd` in its user data failed. Even if you give the existing instance a public address now, there's no web server running on it.

## How to fix it

Open `main.tf` and turn on auto-assign for the subnet:

```hcl
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true

  tags = {
    Name = "trace-the-fault-lab-06-public-subnet"
  }
}
```

Then apply the change **and replace the instance** so it's launched again with a public IP and runs its user data with internet access:

```bash
terraform apply -replace="aws_instance.web"
```

A plain `terraform apply` only updates the subnet setting in place. The existing instance stays exactly as it is, with no public IP and no web server.

### Alternative: fix it on the instance

You can instead ask for the public IP on the instance itself:

```hcl
resource "aws_instance" "web" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.web.id]
  associate_public_ip_address = true

  ...
}
```

Changing `associate_public_ip_address` forces Terraform to replace the instance, so a plain `terraform apply` is enough here. The difference is scope: the subnet setting applies to every instance launched into the subnet, while the instance setting only applies to this one. For a subnet that's meant to be public, fixing the subnet is usually the better choice.

### What about an Elastic IP?

Attaching an Elastic IP to the current instance gives it a public address without replacing it, but the page still won't load, because `httpd` was never installed. User data only runs on the first boot. You would have to connect to the instance and install the web server by hand, which defeats the point of having it in Terraform.

## Verify

Once the new instance has booted (give it a couple of minutes), check the outputs:

```bash
terraform output
```

`instance_public_ip` should now have a value and `web_url` should contain a full DNS name. Load `web_url` in your browser and you should see the "Greetings from the cloud!" page.

## Why this happens

Being a "public subnet" isn't a single setting in AWS. It's the result of two separate things that both have to be true for an instance to be reachable from the internet:

1. **The route:** the subnet's route table sends `0.0.0.0/0` to an internet gateway attached to the VPC.
2. **The address:** the instance has a public IPv4 address (auto-assigned at launch or an Elastic IP), so the internet gateway has something to translate its private address to.

This lab had the first and not the second. The default VPC's subnets have auto-assign turned on, which is why instances there "just work". Custom subnets, whether created in the console or with Terraform, have it turned off unless you ask for it.

Also remember that auto-assign is a launch-time decision. Changing the subnet setting never adds a public IP to an instance that's already running, so after fixing it you always need to launch a new instance.

</details>
