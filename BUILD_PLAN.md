# Build Plan — W15 onwards

Realistic pace: **one meaningful commit per weekday.**
Quality over streak. Each commit should add or improve something real.

---

## Phase 1 — Hub-Spoke Foundation (W15–W16)

| Day | Commit Target |
|---|---|
| W15 Mon | ✅ Scaffold hub-spoke Terraform: main.tf, variables.tf, outputs.tf, README |
| W15 Tue | Add Firewall Policy rule collection group (network rules — allow DNS, NTP) |
| W15 Wed | Add Bastion resource + NSG for AzureBastionSubnet |
| W15 Thu | Add Private DNS zones module (privatelink.database.windows.net, blob, vaultcore) |
| W15 Fri | Add GitHub Actions workflow: terraform fmt + validate on PR |
| W16 Mon | Begin Bicep equivalent — main.bicep, hub VNet + subnets |
| W16 Tue | Bicep: spokes + peering |
| W16 Wed | Bicep: Firewall + DNS Resolver |
| W16 Thu | Bicep: outputs + README |
| W16 Fri | Cross-check: verify Terraform and Bicep produce equivalent architectures |

## Phase 2 — Landing Zone (W17–W18)

- Management group hierarchy module
- Azure Policy assignments (deny non-approved regions, require tags, enforce private endpoints)
- Subscription vending scaffold

## Phase 3 — AKS Cluster (W19–W20)

- AKS cluster: Azure CNI Overlay, Workload Identity, AGIC option
- Key Vault + Secrets Store CSI Driver
- Container Insights + Prometheus scraping config

## Phase 4 — M365 PowerShell Toolkit (parallel, W15 onwards)

| Week | Script |
|---|---|
| W15 | bulk-license-assign.ps1 |
| W16 | offboarding-cleanup.ps1 |
| W17 | windows-cleanup.ps1 |
| W18 | mac-cleanup.sh |
| W19 | license-usage-report.ps1 |

---

## Commit message convention

```
feat: add Firewall policy network rule collection
fix: correct subnet delegation for DNS Resolver
docs: update README with hybrid DNS resolution path
refactor: extract VNet peering into reusable module
chore: add terraform fmt pre-commit hook
```

---

## What makes a good portfolio commit

- Solves a real problem an architect faces
- Has a clean README explaining the why, not just the what
- Includes trade-off commentary (not just working code)
- References the Azure Well-Architected Framework or CAF where relevant
