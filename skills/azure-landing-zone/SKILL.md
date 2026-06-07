---
name: azure-landing-zone
description: "Use when designing Azure enterprise-scale landing zones aligned to the Cloud Adoption Framework. USE FOR: design an Azure landing zone, scaffold a management group hierarchy, create a hub networking platform subscription, assign a regulatory policy initiative, vend a new application landing zone. DO NOT USE FOR: single-resource app deployment, AWS organization design, application code generation."
---

# Azure Landing Zone Skill

Design and scaffold Azure enterprise-scale landing zones (ESLZ) aligned to Microsoft's Cloud Adoption Framework (CAF).

## Templates in This Skill

| Template | Purpose |
|---|---|
| `adr-template.md` | Architecture Decision Record for ESLZ design choices |
| `platform-subscription-template.bicep` | Platform subscription (Connectivity, Identity, or Management) |
| `hub-networking-template.bicep` | Hub VNet, Azure Firewall, DNS Private Resolver, Bastion, and gateway |
| `policy-assignment-template.json` | Azure Policy initiative assignment for regulatory baselines |
| `policy-exemption-template.json` | Azure Policy exemption with justification and expiration fields |
| `landing-zone-vending-template.bicep` | Vending a new application landing zone subscription |

## Agent Pairing

Use with `azure-landing-zone` agent. Cross-cutting: `solution-architect` (ADRs), `policy-as-code-compliance` (compliance), `infrastructure-deploy` (Bicep execution).

## References

- [Azure Landing Zones](https://aka.ms/alz)
- [ALZ-Bicep](https://github.com/Azure/ALZ-Bicep)
