# Lab 02 - Troubleshooting Hints

Try working through the problem on your own first. Expand a hint only when you're stuck.

<details>
<summary>Step 1 - Confirm what's actually failing</summary>

Try loading the URL from the `web_url` output in your browser, or from your terminal:

```bash
curl --max-time 5 http://<instance_public_dns>/
```

The request fails or times out. The instance is running, it has a public IP, and the VPC has an internet gateway attached with a route to it. So what else could be stopping this from working?

</details>

<details>
<summary>Step 2 - Try to get onto the instance to look around</summary>

Open the EC2 console, select the instance, and try to connect via **Session Manager**.

It won't connect, the instance doesn't show up as available/managed. SSH is not an option either, since port 22 was never opened on the security group.

Session Manager relies on an agent running on the instance that has to reach AWS's Systems Manager endpoints on its own. Why might that agent be unable to phone home, given the instance already has a public IP and a route to an internet gateway?

</details>

<details>
<summary>Step 3 - Check the security group directly</summary>

Since you can't get inside the instance, check its attached security group from the console instead.

Look at the **Outbound rules** tab. How many rules are listed there?

</details>

<details>
<summary><strong>Ready for the fix? Click to reveal</strong></summary>

## What's actually wrong

The `aws_security_group "web"` resource only declares an `ingress` block, no `egress` block at all. When Terraform manages a security group with inline `ingress`/`egress` blocks, it treats the rule set as authoritative: any rule not declared in the config gets removed, including the default "allow all outbound" rule that AWS automatically attaches to every newly created security group. Because no `egress` block was written, Terraform strips that default rule away, leaving the security group with zero outbound rules.

With no outbound traffic allowed at all, two things fail independently:

- The `user_data` script's `yum install -y httpd` step can't reach any package repo, so `httpd` is never installed or started. Port 80 being open inbound doesn't matter, because there's no web server listening on it.
- The SSM Agent can't reach the Systems Manager endpoints over HTTPS, so the instance never registers as "connected" in Session Manager, which is why Step 2 couldn't get you in to look around directly.

## How to fix it

Open `main.tf` and add an egress block inside the `aws_security_group "web"` resource:

```hcl
egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
}
```

Adding this rule fixes the security group, but the instance that's already running already failed its one and only `user_data` run, cloud-init doesn't retry it on reboot. So the security group fix alone won't make the page start working; the instance needs to be replaced so it boots fresh with outbound access in place:

```bash
terraform apply 
```

Refresh the browser or re-test once the new instance has had a minute to boot:

```bash
curl --max-time 5 http://<instance_public_dns>/
```

You should now see the "Greetings from the cloud! You solved the lab!" page load successfully.

## Why this happens

It's easy to assume a new security group always allows outbound traffic by default, since that's true when you create one manually in the AWS console. But when Terraform's `aws_security_group` resource declares rules inline, it takes full ownership of that rule set, including removing rules you never asked it to remove. Leaving out an `egress` block isn't "use the default," it's "there should be no egress rules." Always check a security group's actual rule list on both the inbound and outbound sides, not just what you assume AWS provides by default.


</details>
