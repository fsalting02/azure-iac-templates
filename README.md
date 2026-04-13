# azure-iac-templates

Reference infrastructure-as-code templates for common Azure architecture patterns.

Each pattern is implemented in both **Terraform** and **Bicep** — same architecture, two toolchains.

## Patterns

| Pattern | Terraform | Bicep | Status |
|---|---|---|---|
| Hub-Spoke Network | ✅ | 🔜 | Terraform complete |
| Landing Zone | 🔜 | 🔜 | Planned |
| AKS Cluster | 🔜 | 🔜 | Planned |
| Azure Firewall Rules | 🔜 | 🔜 | Planned |

## Design Principles

- Governance before workloads — policy and identity first
- Hub-spoke default; Virtual WAN evaluated per client topology
- Private Endpoints for all PaaS; public endpoints disabled in production
- Secrets via Key Vault only — never in templates or state
- Drift treated as an incident — detect and resolve within 24 hours

## Usage

Each pattern folder contains a `terraform/` and `bicep/` subfolder with its own README, inputs, outputs, and usage example.

## Author

Frank Salting — Azure Cloud Architect
