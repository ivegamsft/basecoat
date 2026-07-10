# Azure IaC Examples

These examples are intentionally small. They are starter references for how Base Coat expects Azure infrastructure samples to be organized.

## Included

- `bicep/storage-account/`: sample Bicep template and parameter file
- `terraform/storage-account/`: sample Terraform layout with version pinning, variables, and outputs

## Notes

- These are starter examples, not production-ready enterprise modules
- Use pinned versions and org-specific naming and tagging before rollout
- Validate with `bicep build`, `terraform fmt`, and `terraform validate` before deployment
