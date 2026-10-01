# Lab 08 - Troubleshooting Hints

Try working through the problem on your own first. Expand a hint only when you're stuck.

<details>
<summary>Step 1 - What kind of failure is it?</summary>

Pay attention to *how* the page fails. Does the browser get an error back straight away, or does it sit there spinning until it gives up?

A long wait followed by a timeout means your packets are being silently dropped somewhere along the way. Nothing is answering at all, not even with a "connection refused". That points at the network path, not at the web server.

Check the obvious layers first:

- Does the instance have a public IP?
- Does the subnet's route table send `0.0.0.0/0` to the internet gateway?
- Does the security group allow port 80 in?

If all of those look right, what else sits between the internet and the instance?

</details>

<details>
<summary>Step 2 - The other firewall</summary>

A subnet has two firewalls in front of an instance: the **security group** on the instance, and the **network ACL** on the subnet.

Open the VPC console, select `trace-the-fault-lab-08-public-subnet` and open its **Network ACL** tab. Read through the inbound rules. Is there a rule that allows HTTP? Is there a rule that denies it?

When a packet matches both an allow rule and a deny rule, which one wins?

</details>

<details>
<summary>Step 3 - How a network ACL reads its rules</summary>

A network ACL doesn't look at every rule and decide. It checks the rules **in order of rule number, lowest first**, and stops at the **first** rule that matches the packet. Whatever that rule says, allow or deny, is final. Rules with higher numbers are never looked at.

In the console the rules are already sorted by number. In `main.tf` they're listed in whatever order they were written. Look at `aws_network_acl "public"` again and sort the inbound rules by `rule_no` in your head. Which rule does an HTTP packet from your browser match first?

</details>

<details>
<summary><strong>Ready for the fix? Click to reveal</strong></summary>

## What's actually wrong

The "deny everything else" rule has a **lower** rule number than the allow rules:

```hcl
#Allow HTTP in
ingress {
  rule_no    = 200
  action     = "allow"
  ...
}

#Allow return traffic for outbound connections
ingress {
  rule_no    = 210
  action     = "allow"
  ...
}

#Deny everything else
ingress {
  rule_no    = 100
  protocol   = "-1"
  action     = "deny"
  cidr_block = "0.0.0.0/0"
  ...
}
```

It is written last in the file, so it reads like a catch-all at the bottom. But AWS ignores the order in the file and only looks at `rule_no`. The actual evaluation order is:

| Rule # | Type | Port range | Source | Action |
|--------|------|------------|--------|--------|
| 100 | All traffic | All | 0.0.0.0/0 | **DENY** |
| 200 | TCP | 80 | 0.0.0.0/0 | ALLOW |
| 210 | TCP | 1024-65535 | 0.0.0.0/0 | ALLOW |
| * | All traffic | All | 0.0.0.0/0 | DENY |

Every inbound packet matches rule 100 first and is dropped. Rules 200 and 210 never get a chance to run.

The knock-on effect:

- Your browser's request on port 80 is dropped, so the page times out.
- The instance's own outbound traffic is allowed by the egress rule, but network ACLs are **stateless**, so the replies coming back from the package repositories are treated as new inbound traffic. They hit rule 100 too and are dropped. This means `dnf install httpd` in the user data can't finish either.

## How to fix it

There are two ways to fix it in `main.tf`. Either one works.

### Option 1: give the deny rule a higher number

Change its `rule_no` to a number **higher** than the allow rules, so it really is evaluated last:

```hcl
#Deny everything else
ingress {
  rule_no    = 300
  protocol   = "-1"
  action     = "deny"
  cidr_block = "0.0.0.0/0"
  from_port  = 0
  to_port    = 0
}
```

### Option 2: delete the deny rule

Remove the whole `#Deny everything else` ingress block. You don't lose anything by doing this. Every network ACL already ends with a built-in `*` rule that denies anything not matched by an earlier rule, so "deny everything else" still happens without it.

### Why not just change it to `allow`?

Changing `action = "deny"` to `action = "allow"` makes the page load, but it isn't a fix. Rule 100 would then allow **all traffic on all ports from anywhere**, and because it's checked first, every inbound packet would be allowed before any other rule is looked at. The network ACL was added to lock the subnet down, and this would turn it into a firewall that blocks nothing.

### Apply the fix

Whichever option you chose, apply it:

```bash
terraform apply
```

Terraform updates the network ACL rules in place. Nothing else changes.

The instance doesn't need to be replaced. Its user data retries the install every few seconds until it succeeds, so once the return traffic is allowed in, `httpd` gets installed on the next attempt.

## Verify

Give it a minute or two after the apply finishes, then load `web_url` in your browser. You should see the "Greetings from the cloud!" page.

## Why this happens

Security groups and network ACLs look similar, but they make decisions in different ways:

| | Security group | Network ACL |
|---|---|---|
| Rule types | Allow only | Allow and deny |
| How rules are evaluated | All rules together, any allow is enough | In number order, first match wins |
| Return traffic | Allowed automatically (stateful) | Must be allowed explicitly (stateless) |

Because of first match wins, a broad deny placed before a narrower allow cancels it completely. The rule to remember: **specific allows get low numbers, broad denies get high numbers.**

As Option 2 showed, a broad "deny everything else" rule is never needed, because the built-in `*` rule already does that job. Explicit deny rules are most useful when they're **narrow**, for example blocking one bad CIDR range with a low number, placed in front of a broad allow.

Leave gaps between rule numbers (100, 200, 300 or 100, 110, 120) so you can add a rule in between later without renumbering everything.

</details>
