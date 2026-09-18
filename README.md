# Trace the Fault

**Hands-on AWS networking labs, built with Terraform, where you find and fix the bug yourself.**

Trace the Fault is a collection of intentionally broken AWS networking environments. Each lab deploys a working-looking setup with one specific issue hidden somewhere in the configuration, a missing route, an unattached gateway, a misordered rule, a security group with no inbound access. Your job is to diagnose it the way you would in production: test, observe, narrow it down, understand the root cause, then fix it.

No answers are handed to you up front. Every lab includes a set of progressive hints if you get stuck, and a full walkthrough once you're ready to check your work.

---

## Why this exists

Most tutorials show you how to build something that works. They rarely teach you how to figure out why something *doesn't*. Real-world AWS networking issues, timeouts, unreachable instances, broken peering, are diagnostic problems, not tutorial-following problems. Trace the Fault is built around that gap: you get infrastructure that's already deployed and already broken, and the skill being practiced is troubleshooting itself.

---

## How the labs are organized

Labs are grouped into three tiers of increasing difficulty:

| Tier | What to expect |
|------|-----------------|
| **Easy** | One misconfigured resource, a direct symptom. Good for building the basic habit of checking each layer. |
| **Intermediate** | Two or more plausible causes. Requires ruling things out before landing on the actual issue. |
| **Advanced** | Multi-resource or cross-service issues, sometimes only visible under specific conditions. Closer to real production debugging. |

Each lab lives in its own folder and is fully self-contained:

```
labs/
  easy/
    lab-01/
    lab-02/
    ...
  intermediate/
    lab-09/
    ...
  advanced/
    lab-19/
    ...
```

Every lab folder includes:

| File | Purpose |
|------|---------|
| `main.tf`, `variables.tf`, `outputs.tf` | The Terraform configuration for that lab, including the bug |
| `README.md` | The scenario and your task, no hints, no spoilers |
| `SOLUTION.md` | Progressive, click-to-expand hints, followed by the full fix |

You can jump into any single lab folder and run it independently, you don't need to touch or even look at the other labs.

---

## Requirements

- **Terraform** installed locally (v1.x or later)
- **AWS CLI** installed and configured with credentials that have permission to create VPC, EC2, and related networking resources
- An **AWS account** (labs use small, low-cost resources like `t3.micro`, but you're responsible for any charges incurred while a lab is running)

New to setting any of this up? Follow this guide first:
**[Step-by-Step Guide to Setting Up Terraform, AWS CLI, and Your AWS Environment](https://medium.com/@eve.maina/step-by-step-guide-to-setting-up-terraform-aws-cli-and-your-aws-environment-fbc13143315d)**

---

## Running a lab

```bash
cd labs/easy/lab-01
terraform init
terraform apply
```

Once applied, check the lab's `README.md` for the specific scenario and what to test. When you're done, always tear the lab down:

```bash
terraform destroy
```

---

## A note on the hints

Try to solve each lab before opening `SOLUTION.md`. The hints are structured to guide your investigation step by step rather than hand you the answer immediately, expand one at a time, and only move to the next if you're genuinely stuck. The full fix is included at the end of every hint file once you're ready to check your work or compare your approach.

---

## Contributing / feedback

This repo is a work in progress, more labs are being added across all three tiers. If you spot an issue with a lab or have a suggestion, feel free to open an issue.

---

Built by [Eve Maina](https://www.linkedin.com/in/eve-maina/)