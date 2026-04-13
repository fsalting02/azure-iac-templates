# Hub-Spoke Network — Terraform

Deploys a production-ready Azure hub-spoke network topology.

## Architecture

```
Hub VNet (10.0.0.0/16)
├── GatewaySubnet        — VPN Gateway (BGP, zone-redundant)
├── AzureFirewallSubnet  — Azure Firewall (zone-redundant, policy-based)
├── AzureBastionSubnet   — Bastion (no public VM IPs required)
└── snet-dns-resolver    — DNS Private Resolver inbound endpoint
    │
    ├── Spoke: workload-a (10.1.0.0/16)
    │   ├── snet-app
    │   └── snet-data
    │
    └── Spoke: workload-b (10.2.0.0/16)
        └── snet-app
```

All spoke egress routes via UDR → Azure Firewall private IP.
All spoke DNS resolves via DNS Private Resolver inbound endpoint.

## What This Deploys

| Resource | Notes |
|---|---|
| Hub VNet + subnets | Gateway, Firewall, Bastion, DNS Resolver |
| Spoke VNets + subnets | Defined via `spokes` variable |
| VNet Peering | Hub ↔ each spoke, gateway transit enabled |
| Route Tables (UDR) | 0.0.0.0/0 → Firewall private IP on each spoke |
| Azure Firewall | Zone-redundant, Standard or Premium, DNS proxy enabled |
| Firewall Policy | Threat intelligence Alert mode |
| DNS Private Resolver | Inbound endpoint with static IP |
| VPN Gateway | Zone-redundant, BGP enabled — optional |

## Prerequisites

- Terraform >= 1.5.0
- Azure CLI authenticated (`az login`)
- Contributor on target subscription
- Remote state backend configured (Azure Storage)

## Usage

```bash
# 1. Copy and edit example vars
cp terraform.tfvars.example terraform.tfvars

# 2. Initialise with your remote backend
terraform init \
  -backend-config="resource_group_name=rg-tfstate" \
  -backend-config="storage_account_name=stfstateprod" \
  -backend-config="container_name=tfstate" \
  -backend-config="key=hub-spoke/terraform.tfstate"

# 3. Review plan
terraform plan -out=tfplan

# 4. Apply
terraform apply tfplan
```

## Key Outputs

| Output | Use |
|---|---|
| `firewall_private_ip` | Next-hop IP for UDRs on additional spokes |
| `dns_resolver_inbound_ip` | Conditional forwarder target for on-prem DNS |
| `spoke_vnet_ids` | Spoke VNet IDs for downstream modules |
| `vpn_gateway_bgp_address` | BGP peer IP for on-prem VPN device config |

## Hybrid Private Endpoint DNS

For on-prem clients to resolve Private Endpoints through this hub:

```
On-prem DNS
  └── Conditional forwarder: privatelink.*.windows.net → dns_resolver_inbound_ip
        └── Azure DNS Private Resolver
              └── Private DNS Zone (linked to hub VNet)
                    └── A record → private endpoint IP
```

Without this forwarder, on-prem clients resolve the public FQDN and bypass
the private endpoint — even if the public endpoint is disabled.

## Design Decisions

**Firewall SKU:** Standard by default. Use Premium when TLS inspection, IDPS,
or URL category filtering is required. Validate against threat model before
selecting — Premium adds meaningful cost.

**Gateway transit:** Spokes reach on-prem via the hub gateway without deploying
their own gateway. `allow_gateway_transit = true` on hub, `use_remote_gateways = true`
on spoke.

**BGP on VPN Gateway:** Required for dynamic route exchange with on-prem and
for ER+VPN coexistence failover via route pre-advertisement.

**Zone redundancy:** Firewall, Gateway, and Bastion public IPs are zone-redundant.
Remove `zones` argument for regions without availability zone support.

## Bicep Equivalent

See `../bicep/` — same architecture, Azure-native toolchain, no state file.