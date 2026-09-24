# Lab 03 - Troubleshooting Hints

Try working through the problem on your own first. Expand a hint only when you're stuck.

<details>
<summary>Step 1 - Confirm what's actually failing</summary>

Try loading the URL from the `web_url` output in your browser, or from your terminal:

```bash
curl --max-time 5 http://<instance_public_dns>/
```

The request hangs and eventually times out. The instance is running, it has a public IP, and the security group allows port 80 in and everything out. So the problem is probably not at the instance boundary. What sits between the internet and that subnet?

</details>

<details>
<summary>Step 2 - Look at the subnet's route table</summary>

Open the VPC console, select the subnet named `trace-the-fault-lab-03-public-subnet`, and open its **Route table** tab.

What routes are listed there? Is there anything that sends traffic destined for the internet (`0.0.0.0/0`) anywhere?

</details>

<details>
<summary>Step 3 - Look at the internet gateway</summary>

Go to **Internet gateways** in the VPC console and find `trace-the-fault-lab-03-igw`.

Check its **State** column and which VPC it's attached to. A subnet only becomes "public" when its route table sends internet traffic to an internet gateway that is attached to the same VPC. The subnet's name and its public IP setting don't make it public on their own.

</details>

<details>
<summary><strong>Ready for the fix? Click to reveal</strong></summary>

## What's actually wrong

The internet gateway was created, but it was never attached to the VPC. The `aws_internet_gateway "myigw"` resource has no `vpc_id`, so it exists in the account in a **Detached** state. And because a route can't point at a gateway that isn't attached to the VPC, the subnet's route table has no `0.0.0.0/0` route either, only the default `local` route for traffic inside the VPC.

The result is a subnet that is named "public" and hands out public IPs, but has no path to or from the internet at all:

- Requests from your browser to the instance's public IP have nowhere to enter the VPC, so they time out.
- The `user_data` script's `yum install -y httpd` step can't reach any package repo, so `httpd` is never installed or started.

## How to fix it

Open `main.tf` and attach the internet gateway to the VPC by adding `vpc_id` to the `aws_internet_gateway "myigw"` resource:

```hcl
resource "aws_internet_gateway" "myigw" {
    vpc_id = aws_vpc.myvpc.id

    tags = {
      Name = "trace-the-fault-lab-03-igw"
    }
}
```

Then add a default route to it inside the `aws_route_table "mypublicrt"` resource:

```hcl
route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.myigw.id
}
```

Fixing the network isn't enough by itself. The instance that's already running already failed its one and only `user_data` run, and cloud-init doesn't retry it on reboot. Apply the fix and replace the instance so it boots fresh with internet access in place:

```bash
terraform apply -replace="aws_instance.web"
```

Refresh the browser or re-test once the new instance has had a minute to boot:

```bash
curl --max-time 5 http://<instance_public_dns>/
```

You should now see the "Greetings from the cloud! You solved the lab!" page load successfully.

## Why this happens

In AWS, "public subnet" isn't a setting, it's a consequence of routing. A subnet is public only when its route table has a route to an internet gateway, and that gateway is attached to the VPC. Naming a subnet `public` and enabling `map_public_ip_on_launch` gives instances a public IP, but without an attached gateway and a route to it, that IP is unreachable. Creating an internet gateway is only half the job; always check that it's attached and that the subnet's route table actually uses it.

</details>
