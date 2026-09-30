# Lab 05 - Troubleshooting Hints

Try working through the problem on your own first. Expand a hint only when you're stuck.

<details>
<summary>Step 1 - Confirm what's actually failing</summary>

Open **Systems Manager > Fleet Manager** in the console, or run:

```bash
aws ssm describe-instance-information --region us-east-1
```

The instance isn't listed, and the **Connect** button in the EC2 console says the SSM Agent isn't online. The instance is running, it has the right IAM role, and the security group allows all outbound traffic.

The SSM agent reaches out to the Systems Manager service over HTTPS to register itself. So the real question is: can this instance reach anything outside the VPC at all?

</details>

<details>
<summary>Step 2 - Look at the private subnet's route table</summary>

Open the VPC console, select the subnet named `trace-the-fault-lab-05-private-subnet`, and open its **Route table** tab.

What routes are listed there? Where does traffic going to `0.0.0.0/0` go?

Compare it with the route table on `trace-the-fault-lab-05-public-subnet`.

</details>

<details>
<summary>Step 3 - Find something to route to</summary>

The private route table has no default route. Before adding one, ask: what would it point at?

Pointing it at the internet gateway won't help. The instance has no public IP, so the internet gateway has no public address to translate its traffic to, and replies would have nowhere to come back to. A private subnet needs a device that sits in the public subnet and sends traffic out on the instance's behalf.

Go to **NAT gateways** in the VPC console and filter by this lab's VPC. What's there?

</details>

<details>
<summary><strong>Ready for the fix? Click to reveal</strong></summary>

## What's actually wrong

There is no NAT gateway in this VPC at all. The private subnet's route table (`aws_route_table "private"`) only has the default `local` route for traffic inside the VPC, and there is nothing in the VPC it could send internet traffic to.

So every packet the instance sends to an address outside the VPC is dropped:

- The SSM agent can't reach the Systems Manager endpoints, so it never registers and Session Manager has nothing to connect to.
- Package updates (`dnf`) and any other outbound calls fail the same way.

## How to fix it

You need three things: an Elastic IP, a NAT gateway in the **public** subnet that uses it, and a default route from the private subnet to that NAT gateway.

Open `main.tf` and add the Elastic IP and NAT gateway after the public route table association:

```hcl
#Elastic IP for the NAT gateway
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "trace-the-fault-lab-05-nat-eip"
  }
}

#NAT Gateway
resource "aws_nat_gateway" "mynat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id

  tags = {
    Name = "trace-the-fault-lab-05-nat"
  }

  depends_on = [aws_internet_gateway.myigw]
}
```

Then add a default route to the NAT gateway inside the `aws_route_table "private"` resource:

```hcl
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.mynat.id
  }

  tags = {
    Name = "trace-the-fault-lab-05-private-route-table"
  }
}
```

A few things to get right:

- `subnet_id` on the NAT gateway must be the **public** subnet. A NAT gateway in the private subnet would have no route to the internet gateway itself.
- The route uses `nat_gateway_id`, not `gateway_id`. `gateway_id` is for internet gateways and virtual private gateways.
- `depends_on` makes sure the internet gateway exists before the NAT gateway is created, since the NAT gateway needs it to reach the internet.

Optionally, add an output to `outputs.tf` so you can verify the traffic path later:

```hcl
output "nat_gateway_public_ip" {
  description = "Public IP of the NAT gateway"
  value       = aws_eip.nat.public_ip
}
```

Apply the fix:

```bash
terraform apply
```

The NAT gateway takes a minute or two to become **Available**. You don't need to replace the instance. The SSM agent keeps retrying in the background, so once the route works it registers on its own. Give it a few minutes and check Fleet Manager again. If it still hasn't shown up after about 10 minutes, reboot the instance to restart the agent.

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

A subnet is only "private" because its route table has no direct path to an internet gateway. That's the point, but it also means the subnet can't get out at all unless you give it another way. The internet gateway can't do it: it only translates addresses for instances that have a public IP, and private instances don't.

A NAT gateway fills that gap. It lives in a public subnet, has its own Elastic IP, and rewrites outbound traffic from private instances so it appears to come from that Elastic IP. Replies come back to the NAT gateway, which forwards them to the right instance. Nothing from the internet can start a connection in.

The full path out of a private subnet has three parts, and all of them have to exist:

1. The private route table sends `0.0.0.0/0` to a NAT gateway.
2. The NAT gateway sits in a **public** subnet and has an Elastic IP.
3. That public subnet's route table sends `0.0.0.0/0` to an internet gateway attached to the VPC.

In Lab 04 the NAT gateway existed but nothing routed to it. Here, parts 1 and 2 are missing entirely. Either way, you check each part of the path in order.

</details>
