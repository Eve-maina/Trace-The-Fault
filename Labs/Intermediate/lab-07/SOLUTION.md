# Lab 07 - Troubleshooting Hints

Try working through the problem on your own first. Expand a hint only when you're stuck.

<details>
<summary>Step 1 - What is the load balancer telling you?</summary>

The browser shows **502 Bad Gateway**. That error comes from the load balancer, not from your instance: the load balancer is up and reachable, but it couldn't get a valid response from the target behind it.

Open **EC2 > Target groups**, select `trace-the-fault-lab-07-tg` and open the **Targets** tab. What is the health status of the instance, and what reason does it give?

The health check is failing because nothing on the instance is answering on port 80. The web server is supposed to be installed by the user data at boot, and installing packages needs outbound internet access. So the real question is: can this instance reach the internet?

</details>

<details>
<summary>Step 2 - Follow the traffic out of the private subnet</summary>

Open the VPC console, select `trace-the-fault-lab-07-private-subnet` and open its **Route table** tab. Where does `0.0.0.0/0` go?

It goes to the NAT gateway, which looks right. But the NAT gateway is not the end of the path. It still has to send the traffic on to the internet gateway, and to do that it uses the route table of **the subnet it lives in**.

Open **NAT gateways**, select `trace-the-fault-lab-07-nat` and check its **Subnet**. Then look at that subnet's route table. Where does `0.0.0.0/0` go from there?

</details>

<details>
<summary>Step 3 - Where does a NAT gateway belong?</summary>

A NAT gateway translates the instance's private address to its own Elastic IP and passes the traffic to the internet gateway. For that last hop to work, the NAT gateway has to sit in a subnet whose route table sends `0.0.0.0/0` to the internet gateway.

Which subnets in this VPC have that route? Look at `aws_nat_gateway "nat"` in `main.tf`. Which subnet is it placed in?

</details>

<details>
<summary><strong>Ready for the fix? Click to reveal</strong></summary>

## What's actually wrong

The NAT gateway was created in the **private** subnet:

```hcl
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.private.id
  ...
}
```

The private subnet's route table sends `0.0.0.0/0` to the NAT gateway, and the NAT gateway lives in that same subnet. So when the NAT gateway tries to forward traffic to the internet, the route it follows points back at itself. Nothing ever reaches the internet gateway, so outbound traffic from the instance goes nowhere.

AWS doesn't stop you from doing this. A NAT gateway can be created in any subnet, and having an Elastic IP doesn't make it work. Everything looks healthy in the console: the NAT gateway shows **Available**, the route shows **Active**, and the Elastic IP is attached.

The knock-on effect:

- The user data on the instance can't reach the package repositories, so `dnf install httpd` keeps failing.
- Nothing is listening on port 80, so the target group health check fails.
- The load balancer has no healthy target to send requests to and returns **502 Bad Gateway**.

## How to fix it

Open `main.tf` and move the NAT gateway into a public subnet:

```hcl
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_a.id

  tags = {
    Name = "trace-the-fault-lab-07-nat"
  }

  depends_on = [aws_internet_gateway.myigw]
}
```

Then apply:

```bash
terraform apply
```

Look at the plan before confirming. A NAT gateway can't be moved between subnets, so Terraform **replaces** it: it destroys the old one, creates a new one with the same Elastic IP, and updates the private route table in place to point at the new NAT gateway ID. Replacing a NAT gateway takes a few minutes.

The instance doesn't need to be replaced. Its user data retries the install every few seconds until it succeeds, so once the new NAT gateway is up, `httpd` gets installed on the next attempt.

## Verify

Watch the **Targets** tab of `trace-the-fault-lab-07-tg`. Within a minute or two of the apply finishing, the instance should change to **healthy**. Load `web_url` in your browser and you should see the "Greetings from the cloud!" page.

## Why this happens

Traffic from a private subnet to the internet takes two hops, and each hop uses a different route table:

1. **Instance to NAT gateway:** uses the route table of the instance's subnet, which sends `0.0.0.0/0` to the NAT gateway.
2. **NAT gateway to internet gateway:** uses the route table of the NAT gateway's subnet, which has to send `0.0.0.0/0` to the internet gateway.

This lab had the first hop and not the second. Putting the NAT gateway in the private subnet is an easy mistake to make, because it's the private subnet that needs the NAT. The rule to remember: **a NAT gateway serves private subnets but always lives in a public one.**

In production you would usually run one NAT gateway per availability zone, each in that zone's public subnet, so losing one zone doesn't cut off outbound traffic for the others.

</details>
