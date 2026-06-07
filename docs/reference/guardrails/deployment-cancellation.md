# Guardrail: Pre-Flight Check Before Stopping a Deployment

> **Rule:** Before stopping or cancelling any in-progress infrastructure deployment, you **MUST** run a pre-flight check to understand what is running and assess the blast radius of an interruption.

## Why

Cancelling an active deployment mid-run is rarely safe. Unlike application code — where a cancelled deploy simply leaves the previous version running — an interrupted infrastructure operation can leave Azure resources in a broken state that requires manual cleanup:

| Risk | Examples |
|---|---|
| **Partially-provisioned resources** | Resource group with half its resources created; VNet without subnets; App Service plan without its apps |
| **Mid-rollout traffic split** | Container App revision split across two versions; Traffic Manager profile with inconsistent endpoint weights |
| **Locked / billing-active state** | Paused Fabric capacities still accrue charges; orphaned managed NICs attached to deleted VMs |
| **ARM deployment locks** | A cancelled `az deployment group create` can leave an ARM deployment in `Running` state, blocking future deployments to the same scope |
| **Terraform state drift** | Cancelling `terraform apply` mid-run leaves `.tfstate` partially updated, causing state drift that future plans cannot detect automatically |
| **azd environment inconsistency** | Azure Developer CLI writes environment metadata during provisioning; a hard stop can leave `azure.yaml` and the remote state out of sync |

---

## Scope

This guardrail applies to **any agent or human operator** who is considering stopping, cancelling, or force-terminating any of the following:

- `az deployment group create` / `az deployment sub create` / `az deployment mg create`
- `terraform apply`
- `bicep build` followed by `az deployment ...`
- `azd up` / `azd provision` / `azd deploy`
- Azure Fabric REST API provisioning calls (`PUT /capacities/...`)
- Any GitHub Actions workflow job that wraps one of the above

---

## Pre-Flight Check — Required Steps

Run **all** of the following checks before issuing a stop, cancel, or workflow cancellation:

### Step 1 — Identify What Is Running

```bash
# List all deployments currently in a Running state for a resource group
az deployment group list \
  --resource-group <rg-name> \
  --filter "provisioningState eq 'Running'" \
  --query "[].{name:name, state:properties.provisioningState, timestamp:properties.timestamp}" \
  --output table

# For subscription-level deployments
az deployment sub list \
  --filter "provisioningState eq 'Running'" \
  --query "[].{name:name, state:properties.provisioningState, timestamp:properties.timestamp}" \
  --output table

# For Terraform — list resources tracked in state
terraform state list

# Show current resource details (type, address, provider)
terraform show -json | jq '.values.root_module.resources[] | {address, type, provider_name}'

# For azd
azd env list
azd show
```

### Step 2 — Assess the Blast Radius

Before stopping, answer each question:

| Question | Guidance |
|---|---|
| How far through the deployment is it? | If > 80% complete, letting it finish is almost always safer than stopping. |
| Are any destructive operations pending? | Check deployment template for `DELETE`, `purge`, capacity scale-down, or `DROP` operations still in the queue. |
| Are resources currently locked by ARM? | `az lock list --resource-group <rg>` — a lock means ARM is mid-operation on that resource. |
| Is a Terraform state lock held? | `terraform force-unlock` is destructive; confirm no concurrent apply is running before proceeding. |
| Will billing continue if stopped? | Fabric capacities, Azure OpenAI PTU reservations, and reserved VMs bill regardless of provisioning state. |

### Step 3 — Check for Dependent Downstream Systems

```bash
# Identify resources that depend on what is being deployed
az resource list \
  --resource-group <rg-name> \
  --query "[].{name:name, type:type, provisioningState:properties.provisioningState}" \
  --output table

# Check if any App Service / Container App is using this deployment's outputs
az containerapp list --resource-group <rg-name> \
  --query "[].{name:name, latestRevision:properties.latestRevisionName, trafficSplit:properties.configuration.ingress.traffic}" \
  --output table
```

### Step 4 — Make the Go / No-Go Decision

| Condition | Recommended Action |
|---|---|
| Deployment is > 80% complete | **Let it finish.** Monitor instead of cancelling. |
| Deployment is idempotent and < 20% complete | **Safe to cancel.** Re-run after fix. |
| Destructive operations are in-flight | **Do NOT cancel.** Let the operation complete, then remediate. |
| ARM deployment is stuck `Running` for > 1 hour | **Investigate first.** Check activity log before force-cancelling. |
| Terraform state lock is stale (operator confirmed dead) | **Safe to `force-unlock`**, then cancel. |
| azd environment is inconsistent | **Run `azd env refresh`** before re-provisioning. |

---

## If You Must Stop an In-Progress Deployment

If the pre-flight check confirms a stop is necessary, follow these steps:

### Azure CLI / Bicep

```bash
# Cancel an in-progress ARM deployment (does NOT roll back already-created resources)
az deployment group cancel \
  --name <deployment-name> \
  --resource-group <rg-name>

# Verify the deployment is now Cancelled
az deployment group show \
  --name <deployment-name> \
  --resource-group <rg-name> \
  --query "properties.provisioningState"
```

> **Warning:** `az deployment group cancel` stops further resource creation but does **not** delete resources that have already been created. You must manually clean up or re-run the deployment to reach a known-good state.

### Terraform

```bash
# Terraform does not have a built-in remote cancel.
# In a GitHub Actions workflow: cancel the workflow run via the GitHub UI or API.

# After cancellation, check for a stale state lock:
terraform force-unlock <lock-id>

# Refresh state to detect drift before the next apply:
terraform refresh
terraform plan -out=tfplan
```

### azd

```bash
# If azd is running in a workflow, cancel the workflow run.
# After cancellation, re-sync the local environment:
azd env refresh

# Check what was and was not provisioned:
azd show
```

---

## Remediation After an Unplanned Stop

If a deployment was stopped without running the pre-flight check, follow these remediation steps:

### 1. Audit Resource State

```bash
# List all resources in the RG and their provisioning state
az resource list \
  --resource-group <rg-name> \
  --query "[?properties.provisioningState != 'Succeeded'].{name:name, type:type, state:properties.provisioningState}" \
  --output table

# Check the ARM deployment operation log for the last error
az deployment group operation list \
  --resource-group <rg-name> \
  --name <deployment-name> \
  --query "[?properties.provisioningState == 'Failed'].{resource:properties.targetResource.resourceType, error:properties.statusMessage}" \
  --output json
```

### 2. Choose a Remediation Strategy

| Strategy | When to Use |
|---|---|
| **Re-run the deployment** | If the template is idempotent (ARM complete mode or Terraform) and no destructive ops were mid-flight. |
| **Manual cleanup + re-run** | If orphaned resources block a clean re-run. Delete the partial resources first, then re-deploy. |
| **ARM deployment cancel + cleanup** | If the deployment is still in `Running` state. Cancel first, then clean up partial resources. |
| **Restore from backup / snapshot** | If stateful services (databases, storage) were modified mid-flight. Requires a pre-deployment backup. |

### 3. Prevent Recurrence

- Confirm the workflow has `cancel-in-progress: false` in its concurrency group (see [ci-concurrency.md](ci-concurrency.md)).
- Add a pre-deployment snapshot or resource-group tag with the last-known-good deployment name.
- Use ARM complete-mode or Terraform's `-target` flag sparingly and only when the scope is well understood.
- Consider adding an `az deployment group wait` step to monitor progress rather than cancelling.

---

## References

- [Azure ARM deployment cancellation](https://learn.microsoft.com/en-us/azure/azure-resource-manager/templates/deploy-cli#cancel-a-running-deployment)
- [Terraform: Handling interrupts](https://developer.hashicorp.com/terraform/cli/commands/apply#interrupts)
- [Azure Developer CLI (`azd`) environment management](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/manage-environment-variables)
- Governance: [`instructions/basecoat-20-lang-governance.instructions.md`](/instructions/basecoat-20-lang-governance.instructions.md)
- Related guardrail: [`docs/guardrails/db-deployment-concurrency.md`](db-deployment-concurrency.md)
- Related guardrail: [`docs/guardrails/ci-concurrency.md`](ci-concurrency.md)
