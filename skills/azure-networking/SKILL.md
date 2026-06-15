---
name: azure-networking
description: "Use when designing Azure network topology, private connectivity, and traffic control patterns. USE FOR: design a hub-spoke VNet topology, set up private endpoints and Private DNS zones, author an NSG rule matrix, create forced-tunneling route tables, review hybrid connectivity on Azure. DO NOT USE FOR: identity role assignments, Kubernetes app manifests, non-Azure CDN setup."
compatibility:
  - GHCP
---
# Azure Networking Skill

Design Azure network architectures: hub-spoke topologies, private endpoints, DNS zones,
NSG rules, Azure Firewall policies, and forced-tunneling route tables.

## Reference Files

| File | Contents |
|------|----------|
| [`references/workflow.md`](references/workflow.md) | 6-step design workflow: requirements → hub-spoke → private endpoints → NSG/Firewall → UDR → validation |
| [`references/guardrails.md`](references/guardrails.md) | Design guardrails, agent pairing guidance, and external references |
| [`templates/hub-spoke-topology.md`](templates/hub-spoke-topology.md) | Mermaid diagram scaffold for hub-spoke VNet topology |
| [`templates/cidr-allocation.md`](templates/cidr-allocation.md) | CIDR allocation table for hub, spokes, and subnets |
| [`templates/private-endpoint-dns-zones.md`](templates/private-endpoint-dns-zones.md) | PaaS service → private endpoint → DNS zone mapping |
| [`templates/nsg-rule-matrix.md`](templates/nsg-rule-matrix.md) | NSG inbound/outbound rule matrix per subnet tier |
