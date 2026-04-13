output "hub_vnet_id" {
  description = "Resource ID of the hub VNet"
  value       = azurerm_virtual_network.hub.id
}

output "hub_vnet_name" {
  description = "Name of the hub VNet"
  value       = azurerm_virtual_network.hub.name
}

output "firewall_private_ip" {
  description = "Private IP of the Azure Firewall — use as next-hop in UDRs"
  value       = azurerm_firewall.hub.ip_configuration[0].private_ip_address
}

output "firewall_public_ip" {
  description = "Public IP of the Azure Firewall"
  value       = azurerm_public_ip.firewall.ip_address
}

output "dns_resolver_inbound_ip" {
  description = "Inbound endpoint IP of the DNS Private Resolver — configure as conditional forwarder target on on-prem DNS"
  value       = var.dns_resolver_inbound_ip
}

output "spoke_vnet_ids" {
  description = "Map of spoke name → VNet resource ID"
  value       = { for k, v in azurerm_virtual_network.spokes : k => v.id }
}

output "vpn_gateway_id" {
  description = "Resource ID of the VPN Gateway (null if not deployed)"
  value       = var.deploy_vpn_gateway ? azurerm_virtual_network_gateway.hub[0].id : null
}

output "vpn_gateway_bgp_address" {
  description = "BGP peer IP of the VPN Gateway — use when configuring on-prem VPN device"
  value       = var.deploy_vpn_gateway ? azurerm_virtual_network_gateway.hub[0].bgp_settings[0].peering_addresses[0].default_addresses[0] : null
}
