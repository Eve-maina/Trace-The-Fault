# Lab 01 — Troubleshooting Hints

Try working through the problem on your own first. Expand a hint only when you're stuck.

---

<details>
<summary>Step 1 — Confirm what's actually failing</summary>

Try loading the URL from the `web_url` output in your browser, or from your terminal:

```bash
curl --max-time 5 http://<instance_public_dns>/
```

The request hangs and eventually times out. The instance is running, it has a public IP, and the VPC has an internet gateway attached with a route to it. So what else could be stopping the request from reaching the instance?

</details>

---

<details>
<summary>Step 2 — Look at the security group</summary>

Open the EC2 console, select the instance, and check its attached security group.

Go to the **Inbound rules** tab. How many rules are listed there?

</details>

---

<details>
<summary>Step 3 — Understand what that means</summary>

A security group with no inbound rules blocks all incoming traffic by default. It doesn't matter that outbound traffic is allowed, or that routing to the instance is otherwise correct. Without a rule explicitly permitting traffic in on port 80, any request from the internet gets dropped before it ever reaches the instance's operating system.

Compare that to the outbound rule already present, notice it's the only rule in the group.

</details>

---

<details>
<summary><strong>Ready for the fix? Click to reveal</strong></summary>

## What's actually wrong

The security group attached to the instance has no inbound rule, only an outbound one. Port 80 traffic from the internet is never allowed in, so requests time out even though the instance, subnet, routing, and internet gateway are all correctly configured.

## How to fix it

Open `main.tf` and paste this inside the `aws_security_group "web"` block:

```hcl
ingress {
  from_port   = 80
  to_port     = 80
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}
```

Save the file, then re-apply:

```bash
terraform apply
```

Re-test:

```bash
curl --max-time 5 http://<instance_public_dns>/
```

You should now see the "Greetings from the cloud! You solved the lab!" page load successfully.

## Why this happens

Security groups are stateful, but they still default to denying all inbound traffic until a rule explicitly allows it. A correctly routed, correctly attached network path means nothing if the security group at the instance boundary has no matching inbound rule. Always check a security group's actual rule list, not just that a security group exists.

</details>