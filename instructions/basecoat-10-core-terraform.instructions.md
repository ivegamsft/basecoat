---
description: "Use when creating or reviewing Terraform for Azure or shared infrastructure. Covers provider pinning, state hygiene, modules, validation, and safe Terraform workflows."
applyTo: "**/*.{tf,tfvars}"
---

# Terraform Standards

Use this instruction for Terraform changes, especially when provisioning Azure resources.

## Rules

- Pin Terraform and provider versions so plans stay reproducible across environments.
- Keep variables typed, outputs narrow, and secrets out of committed `.tfvars` files.
- Prefer reusable modules over copy-pasted resource blocks when patterns repeat.
- Treat remote state, locking, and environment separation as part of the design, not cleanup work.

## Expectations

- Pin Terraform and provider versions explicitly.
- Prefer typed variables, clear descriptions, and narrow outputs.
- Keep secrets out of checked-in `.tfvars` files.
- Use modules to share repeated infrastructure patterns instead of copy-paste resources.
- Make tags and naming inputs first-class where the platform requires consistency.
- Run `terraform fmt`, `terraform validate`, and `terraform plan` before apply.
- Treat remote state, locking, and environment separation as part of the design.

## Examples

### Example provider pinning

```hcl
terraform {
  required_version = "~> 1.9.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.1"
    }
  }
}
```

### Example module usage

```hcl
module "network" {
  source              = "../modules/network"
  location            = var.location
  resource_group_name = var.resource_group_name
}
```

## Review Lens

- Are providers versioned and minimal?
- Is the configuration safe to plan and apply repeatedly?
- Are names, tags, and locations consistent with platform standards?
- Is state management defined clearly for team use?
