# Lab 04 - Troubleshooting Hints

Try working through the problem on your own first. Expand a hint only when you're stuck.

<details>
<summary>Step 1 - Confirm what's actually failing</summary>

Open **Systems Manager > Fleet Manager** in the console, or run:

```bash
aws ssm describe-instance-information --region us-east-1
```

The instance isn't listed, and the **Connect** button in the EC2 console says the SSM Agent isn't online. The instance is running, it has the right IAM role, and the security group allows all outbound traffic.

The SSM agent doesn't wait for you to connect to it. It reaches out to the Systems Manager service over HTTPS to register itself. So the real question is: can this instance reach anything outside the VPC at all? How does a private subnet with no public IPs get to the internet?

</details>

<details>
<summary>Step 2 - Look at the private subnet's route table</summary>

Open the VPC console, select the subnet named `trace-the-fault-lab-04-private-subnet`, and open its **Route table** tab.

What routes are listed there? Where does traffic going to `0.0.0.0/0` go?

Compare it with the route table on `trace-the-fault-lab-04-public-subnet`.

</details>

<details>
<summary>Step 3 - Look at the NAT gateway</summary>

Go to **NAT gateways** in the VPC console and find `trace-the-fault-lab-04-nat`.

It's **Available**, it has an Elastic IP, and it sits in the public subnet, so the gateway itself is fine. Now ask: which route table actually sends traffic to it?

</details>

<details>
<summary><strong>Ready for the fix? Click to reveal</strong></summary>

## What's actually wrong

The NAT gateway was created, but nothing uses it. The private subnet's route table (`aws_route_table "private"`) only has the default `local` route for traffic inside the VPC. There's no `0.0.0.0/0` route pointing at the NAT gateway.

So every packet the instance sends to an address outside the VPC is dropped:

- The SSM agent can't reach the Systems Manager endpoints, so it never registers and Session Manager has nothing to connect to.
- Package updates (`dnf`) and any other outbound calls fail the same way.

## How to fix it

Open `main.tf` and add a default route to the NAT gateway inside the `aws_route_table "private"` resource:

```hcl
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.mynat.id
  }

  tags = {
    Name = "trace-the-fault-lab-04-private-route-table"
  }
}
```

Note that it's `nat_gateway_id`, not `gateway_id`. `gateway_id` is for internet gateways and virtual private gateways.

Apply the fix:

```bash
terraform apply
```

Unlike Lab 03, you don't need to replace the instance. The SSM agent keeps retrying in the background, so once the route exists it registers on its own. Give it a few minutes and check Fleet Manager again. If it still hasn't shown up after about 10 minutes, reboot the instance to restart the agent.

Then connect and confirm the instance can reach the internet:

```bash
aws ssm start-session --target <instance_id> --region us-east-1
```

```bash
curl -sI https://aws.amazon.com | head -1
curl -s https://checkip.amazonaws.com
```

The first command should return an HTTP status line. The second should print the same address as the `nat_gateway_public_ip` output, which shows the instance's outbound traffic is leaving through the NAT gateway.

## Why this happens

A NAT gateway isn't "attached" to a subnet the way an internet gateway is attached to a VPC. It's just a target that routes can point at. Creating one does nothing on its own: a private subnet only gets outbound internet access when its route table sends `0.0.0.0/0` to that NAT gateway.

The full path out of a private subnet has three parts, and all of them have to be in place:

1. The private route table sends `0.0.0.0/0` to the NAT gateway.
2. The NAT gateway sits in a **public** subnet and has an Elastic IP.
3. That public subnet's route table sends `0.0.0.0/0` to an internet gateway attached to the VPC.

When a private instance can't reach anything outside the VPC, walk that path in order and check each part.

</details>
