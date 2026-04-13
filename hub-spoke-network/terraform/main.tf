terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
  }

  backend "azurerm" {
    # Configure via CLI or CI pipeline — never hardcode
    # resource_group_name  = "<your-tfstate-rg>"
    # storage_account_name = "<your-tfstate-sa>"
    # container_name       = "tfstate"
    # key                  = "hub-spoke/terraform.tfstate"
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
  }
}

# ── Resource Groups ───────────────────────────────────────────────────────────

resource "azurerm_resource_group" "hub" {
  name     = "rg-${var.prefix}-hub-${var.environment}-${var.location_short}"
  location = var.location
  tags     = local.tags
}

resource "azurerm_resource_group" "spokes" {
  for_each = var.spokes
  name     = "rg-${var.prefix}-${each.key}-${var.environment}-${var.location_short}"
  location = var.location
  tags     = local.tags
}

# ── Hub VNet ──────────────────────────────────────────────────────────────────

resource "azurerm_virtual_network" "hub" {
  name                = "vnet-${var.prefix}-hub-${var.environment}-${var.location_short}"
  resource_group_name = azurerm_resource_group.hub.name
  location            = var.location
  address_space       = [var.hub_address_space]
  dns_servers         = [var.dns_resolver_inbound_ip]
  tags                = local.tags
}

resource "azurerm_subnet" "gateway" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.subnet_gateway]
}

resource "azurerm_subnet" "firewall" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.subnet_firewall]
}

resource "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.subnet_bastion]
}

resource "azurerm_subnet" "dns_resolver_inbound" {
  name                 = "snet-dns-resolver-inbound"
  resource_group_name  = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.subnet_dns_inbound]

  delegation {
    name = "dns-resolver"
    service_delegation {
      name    = "Microsoft.Network/dnsResolvers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

# ── Spoke VNets ───────────────────────────────────────────────────────────────

resource "azurerm_virtual_network" "spokes" {
  for_each = var.spokes

  name                = "vnet-${var.prefix}-${each.key}-${var.environment}-${var.location_short}"
  resource_group_name = azurerm_resource_group.spokes[each.key].name
  location            = var.location
  address_space       = [each.value.address_space]
  dns_servers         = [var.dns_resolver_inbound_ip]
  tags                = local.tags
}

resource "azurerm_subnet" "spoke_subnets" {
  for_each = {
    for item in flatten([
      for spoke_key, spoke in var.spokes : [
        for subnet_key, subnet in spoke.subnets : {
          key        = "${spoke_key}-${subnet_key}"
          spoke_key  = spoke_key
          subnet_key = subnet_key
          address    = subnet.address_prefix
        }
      ]
    ]) : item.key => item
  }

  name                 = "snet-${each.value.subnet_key}"
  resource_group_name  = azurerm_resource_group.spokes[each.value.spoke_key].name
  virtual_network_name = azurerm_virtual_network.spokes[each.value.spoke_key].name
  address_prefixes     = [each.value.address]
}

# ── VNet Peering ──────────────────────────────────────────────────────────────

resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  for_each = var.spokes

  name                      = "peer-hub-to-${each.key}"
  resource_group_name       = azurerm_resource_group.hub.name
  virtual_network_name      = azurerm_virtual_network.hub.name
  remote_virtual_network_id = azurerm_virtual_network.spokes[each.key].id
  allow_forwarded_traffic   = true
  allow_gateway_transit     = true
  use_remote_gateways       = false
}

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  for_each = var.spokes

  name                      = "peer-${each.key}-to-hub"
  resource_group_name       = azurerm_resource_group.spokes[each.key].name
  virtual_network_name      = azurerm_virtual_network.spokes[each.key].name
  remote_virtual_network_id = azurerm_virtual_network.hub.id
  allow_forwarded_traffic   = true
  allow_gateway_transit     = false
  use_remote_gateways       = var.deploy_vpn_gateway

  depends_on = [azurerm_virtual_network_gateway.hub]
}

# ── UDRs — Force Egress via Firewall ─────────────────────────────────────────

resource "azurerm_route_table" "spoke_udr" {
  for_each = var.spokes

  name                          = "rt-${var.prefix}-${each.key}-${var.environment}"
  resource_group_name           = azurerm_resource_group.spokes[each.key].name
  location                      = var.location
  disable_bgp_route_propagation = true
  tags                          = local.tags

  route {
    name                   = "default-to-firewall"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.hub.ip_configuration[0].private_ip_address
  }
}

# ── DNS Private Resolver ──────────────────────────────────────────────────────

resource "azurerm_private_dns_resolver" "hub" {
  name                = "dnsresolver-${var.prefix}-hub-${var.environment}"
  resource_group_name = azurerm_resource_group.hub.name
  location            = var.location
  virtual_network_id  = azurerm_virtual_network.hub.id
  tags                = local.tags
}

resource "azurerm_private_dns_resolver_inbound_endpoint" "hub" {
  name                    = "inbound-${var.prefix}-hub"
  private_dns_resolver_id = azurerm_private_dns_resolver.hub.id
  location                = var.location
  tags                    = local.tags

  ip_configurations {
    private_ip_allocation_method = "Static"
    private_ip_address           = var.dns_resolver_inbound_ip
    subnet_id                    = azurerm_subnet.dns_resolver_inbound.id
  }
}

# ── VPN Gateway ───────────────────────────────────────────────────────────────

resource "azurerm_public_ip" "gateway" {
  count               = var.deploy_vpn_gateway ? 1 : 0
  name                = "pip-${var.prefix}-gw-${var.environment}"
  resource_group_name = azurerm_resource_group.hub.name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  tags                = local.tags
}

resource "azurerm_virtual_network_gateway" "hub" {
  count               = var.deploy_vpn_gateway ? 1 : 0
  name                = "gw-${var.prefix}-hub-${var.environment}"
  resource_group_name = azurerm_resource_group.hub.name
  location            = var.location
  type                = "Vpn"
  vpn_type            = "RouteBased"
  sku                 = var.vpn_gateway_sku
  active_active       = false
  enable_bgp          = true
  tags                = local.tags

  ip_configuration {
    name                          = "gw-ipconfig"
    public_ip_address_id          = azurerm_public_ip.gateway[0].id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.gateway.id
  }

  bgp_settings {
    asn = var.gateway_asn
  }
}

# ── Azure Firewall ────────────────────────────────────────────────────────────

resource "azurerm_public_ip" "firewall" {
  name                = "pip-${var.prefix}-fw-${var.environment}"
  resource_group_name = azurerm_resource_group.hub.name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  tags                = local.tags
}

resource "azurerm_firewall_policy" "hub" {
  name                = "fwpol-${var.prefix}-hub-${var.environment}"
  resource_group_name = azurerm_resource_group.hub.name
  location            = var.location
  sku                 = var.firewall_sku_tier
  tags                = local.tags

  dns {
    proxy_enabled = true
    servers       = [var.dns_resolver_inbound_ip]
  }

  threat_intelligence_mode = "Alert"
}

resource "azurerm_firewall" "hub" {
  name                = "fw-${var.prefix}-hub-${var.environment}"
  resource_group_name = azurerm_resource_group.hub.name
  location            = var.location
  sku_name            = "AZFW_VNet"
  sku_tier            = var.firewall_sku_tier
  zones               = ["1", "2", "3"]
  firewall_policy_id  = azurerm_firewall_policy.hub.id
  tags                = local.tags

  ip_configuration {
    name                 = "fw-ipconfig"
    subnet_id            = azurerm_subnet.firewall.id
    public_ip_address_id = azurerm_public_ip.firewall.id
  }
}
