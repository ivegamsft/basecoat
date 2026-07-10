---
description: "Use when writing GitHub Actions workflows that access firewalled Azure resources (Storage, Key Vault, SQL, Cosmos). Covers the single-job runner IP pattern with guaranteed cleanup."
applyTo: "**/*.yml,**/*.yaml"
---

# CI/CD Runner Firewall Management

Use this instruction for any workflow that needs to access Azure resources behind network firewalls.

## Expectations

- All firewall add/work/remove steps **must** be in a **single job** — runner IPs change between jobs.
- The firewall remove step **must** use `if: always()` to ensure cleanup even on failure.
- Use `az` CLI for firewall changes, **not** Terraform — this avoids state drift.
- Wait 15–30 seconds after adding the IP for Azure propagation.
- Log the IP being added and removed for audit trail.

## Pattern

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Get runner IP
        id: ip
        run: echo "runner_ip=$(curl -s https://api.ipify.org)" >> $GITHUB_OUTPUT

      - name: Check firewall status
        id: fw
        run: |
          DEFAULT_ACTION=$(az storage account show -n ${{ env.STORAGE }} -g ${{ env.RG }} --query networkRuleSet.defaultAction -o tsv)
          echo "is_firewalled=$([[ "$DEFAULT_ACTION" == "Deny" ]] && echo true || echo false)" >> $GITHUB_OUTPUT

      - name: Add runner IP to firewall
        if: steps.fw.outputs.is_firewalled == 'true'
        run: |
          az storage account network-rule add -n ${{ env.STORAGE }} -g ${{ env.RG }} --ip-address ${{ steps.ip.outputs.runner_ip }}
          echo "Added ${{ steps.ip.outputs.runner_ip }} to firewall"
          sleep 20  # Wait for Azure propagation

      # === Do work here (Terraform apply, blob ops, secret reads) ===

      - name: Remove runner IP from firewall
        if: always() && steps.fw.outputs.is_firewalled == 'true'
        run: |
          az storage account network-rule remove -n ${{ env.STORAGE }} -g ${{ env.RG }} --ip-address ${{ steps.ip.outputs.runner_ip }} || true
          echo "Removed ${{ steps.ip.outputs.runner_ip }} from firewall"
```

## Rules

- **Check before modifying**: read `defaultAction` first — skip firewall steps if the resource is not firewalled.
- **Same-job guarantee**: never split firewall add and remove across different jobs.
- **`|| true` on remove**: the IP may already be removed if cleanup ran previously; don't fail the workflow.
- **`az` CLI only**: using Terraform for firewall rules causes state drift when rules are added/removed dynamically.
- **Audit logging**: always echo the IP being added and removed.

## Anti-Patterns

```yaml
# WRONG — firewall add in one job, remove in another (different runner IPs!)
jobs:
  setup:
    steps:
      - run: az storage account network-rule add ...
  deploy:
    needs: setup
    steps:
      - run: az storage account network-rule remove ...

# WRONG — no cleanup on failure
- name: Remove IP
  run: az storage account network-rule remove ...
  # Missing: if: always()
```

## Review Lens

- Is the firewall remove step protected with `if: always()`?
- Are firewall add and remove in the same job?
- Does the workflow check `defaultAction` before modifying firewall rules?
- Is the remove step tolerant of already-removed IPs (`|| true`)?
