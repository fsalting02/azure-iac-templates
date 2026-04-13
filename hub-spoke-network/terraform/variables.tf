variable "prefix" {
  description = "Short prefix applied to all resource names (e.g. 'contoso')"
  type        = string
}

variable "environment" {
  description = "Environment label: dev | staging | prod"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging, or prod."
  }
}

variable "location" {
  description = "Primary Azure region (e.g. 'australiaeast')"
  type        = string
  default     = "australiaeast"
}

variable "location_short" {
  description = "Short location code used in resource names (e.g. 'aue')"
  type        = string
  default     = "aue"
}

# ── Hub address space ─────────────────────────────────────────────────────────

variable "hub_address_space" {
  description = "CIDR block for the hub VNet (e.g. '10.0.0.0/16')"
  type        = string
}

variable "subnet_gateway" {
  description = "CIDR for GatewaySubnet — must be at least /27"
  type        = string
}

variable "subnet_firewall" {
  description = "CIDR for AzureFirewallSubnet — must be at least /26"
  type        = string
}

variable "subnet_bastion" {
  description = "CIDR for AzureBastionSubnet — must be at least /26"
  type        = string
}

variable "subnet_dns_inbound" {
  description = "CIDR for DNS Private Resolver inbound endpoint subnet — must be at least /28"
  type        = string
}

variable "dns_resolver_inbound_ip" {
  description = "Static private IP for DNS Resolver inbound endpoint — must be within subnet_dns_inbound"
  type        = string
}

# ── Spokes ────────────────────────────────────────────────────────────────────

variable "spokes" {
  description = "Map of spoke definitions. Key = spoke name (e.g. 'workload-a')."
  type = map(object({
    address_space = string
    subnets = map(object({
      address_prefix = string
    }))
  }))
  default = {}
}

# ── Gateway ───────────────────────────────────────────────────────────────────

variable "deploy_vpn_gateway" {
  description = "Set to false to skip VPN Gateway deployment (e.g. dev environments)"
  type        = bool
  default     = true
}

variable "vpn_gateway_sku" {
  description = "VPN Gateway SKU (VpnGw1AZ | VpnGw2AZ | VpnGw3AZ)"
  type        = string
  default     = "VpnGw1AZ"
}

variable "gateway_asn" {
  description = "BGP ASN for the VPN Gateway. Default Azure ASN = 65515."
  type        = number
  default     = 65515
}

# ── Firewall ──────────────────────────────────────────────────────────────────

variable "firewall_sku_tier" {
  description = "Azure Firewall tier: Standard | Premium. Premium required for TLS inspection and IDPS."
  type        = string
  default     = "Standard"
  validation {
    condition     = contains(["Standard", "Premium"], var.firewall_sku_tier)
    error_message = "firewall_sku_tier must be Standard or Premium."
  }
}

# ── Tags ──────────────────────────────────────────────────────────────────────

variable "tags" {
  description = "Additional tags merged with default tags"
  type        = map(string)
  default     = {}
}
