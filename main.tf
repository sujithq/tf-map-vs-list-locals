terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 2.84"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_network_ddos_protection_plan" "ddos" {
  name                = "ddos-protection-plan"
  location            = "westeurope"
  resource_group_name = "rg-suqu"
}

# -
# - Virtual Network
# - designed to create multiple VNETs if needed
variable "virtual_networks" {
  description = "The virtual networks with their properties list."
  type = list(object({
    name                = string
    resource_group_name = string
    location            = string
    address_space       = list(string)
    dns_servers         = list(string)
    tags                = map(string)
    ddos_protection_plan = object({
      id     = string
      enable = bool
    })
  }))
  default = [ {
    address_space = [ "10.0.0.0/25" ]
    ddos_protection_plan = {
      enable = false
      id = "/subscriptions/60ff740b-3e7b-4657-86b3-69c0693691e3/resourceGroups/rg-suqu/providers/Microsoft.Network/ddosProtectionPlans/ddos-protection-plan"
    }
    dns_servers = []
    location = "westeurope"
    name = "vnet-suqu-src"
    resource_group_name = "rg-suqu-src"
    tags = {
      "tag1" = "tag1"
      "tag2" = "tag2"
    }
  },{
    address_space = [ "10.0.1.0/25" ]
    ddos_protection_plan = {
      enable = false
      id = "/subscriptions/60ff740b-3e7b-4657-86b3-69c0693691e3/resourceGroups/rg-suqu/providers/Microsoft.Network/ddosProtectionPlans/ddos-protection-plan"
    }
    dns_servers = []
    location = "westeurope"
    name = "vnet-suqu-dst"
    resource_group_name = "rg-suqu-dst"
    tags = {
      "tag3" = "tag3"
      "tag4" = "tag4"
    }
  } ]
}

# -
# - Virtual Network Peering
# -
variable "vnet_peering" {
  description = "Vnet Peering to the destination Vnet"
  type = map(object({
    destination_vnet_name        = string
    destination_vnet_rg          = string
    source_vnet_name             = string
    rg_name                      = string
    allow_virtual_network_access = bool
    allow_forwarded_traffic      = bool
    allow_gateway_transit        = bool
    use_remote_gateways          = bool
  }))
  default = {
    "key" = {
      allow_forwarded_traffic = false
      allow_gateway_transit = false
      allow_virtual_network_access = false
      destination_vnet_name = "vnet-suqu-dst"
      destination_vnet_rg = "rg-suqu-dst"
      rg_name = "rg-suqu-src"
      source_vnet_name = "vnet-suqu-src"
      use_remote_gateways = false
    }
  }
}

# -
# - Subnet object
# - 
variable "subnets" {
  description = "The virtal networks subnets with their properties."
  type = map(object({
    name              = string
    rg_name           = string
    vnet_name         = string
    address_prefixes  = list(string)
    pe_enable         = bool
    service_endpoints = list(string)
    delegation = list(object({
      name = string
      service_delegation = list(object({
        name    = string
        actions = list(string)
      }))
    }))
  }))
  default = {
    "src" = {
      address_prefixes = [ "10.0.0.0/26" ]
      delegation = []
      name = "vnet-suqu-src-snet"
      pe_enable = false
      rg_name = "rg-suqu-src"
      service_endpoints = [ ]
      vnet_name = "vnet-suqu-src"
    }
    "dst" = {
      address_prefixes = [ "10.0.1.0/26" ]
      delegation = []
      name = "vnet-suqu-dst-snet"
      pe_enable = false
      rg_name = "rg-suqu-dst"
      service_endpoints = [ ]
      vnet_name = "vnet-suqu-dst"
    }
  }
}

data "azurerm_resource_group" "this" {
  # read from local variable, index is resource_group_name
  for_each = local.rgs_map
  name     = each.value.name
}

# data "azurerm_virtual_network" "this" {
#   for_each            = var.vnet_peering
#   name                = each.value["source_vnet_name"]
#   resource_group_name = each.value["rg_name"]
#   depends_on          = [azurerm_virtual_network.this,azurerm_network_ddos_protection_plan.ddos]
# }

# -
# - Setup key vault 
# - transform variables to locals to make sure the correct index will be used: resource group name and key vault name

locals {
  rgs_map = {
    for n in var.virtual_networks :
    n.resource_group_name => {
      name = n.resource_group_name
    }
  }
}

# -
# - Virtual Network
# - loop through each VNET defined
resource "azurerm_virtual_network" "this" {
  for_each            = { for n in var.virtual_networks : "${n.name}" => n } #name of virtual network is unique
  name                = each.value.name
  location            = each.value.location
  resource_group_name = each.value.resource_group_name
  address_space       = each.value.address_space
  tags                = merge(each.value.tags, data.azurerm_resource_group.this[each.value.resource_group_name].tags)
  dns_servers         = lookup(each.value, "dns_servers", null) # lookup retrieves the value of a single element from a map, given its key. If the key does not exist, the given default value is returned
  # for each vnet, lookup the DDOS plan. Why is this so complex? This could be much simpler given that we are looking for two values, one of which is just a boolean
  /* Conditional expression example - first, name the condition. Then, if the first part is not empty, assign the value of ddos_protection_plan. Else, do a lookup */
  dynamic "ddos_protection_plan" {
    for_each = lookup(each.value, "ddos_protection_plan", null) != null ? tolist([lookup(each.value, "ddos_protection_plan")]) : []
    content {
      id     = lookup(ddos_protection_plan.value, "id", null)
      enable = coalesce(lookup(ddos_protection_plan.value, "enable"), false)
    }
  }
  depends_on = [data.azurerm_resource_group.this]
}

# -
# - VNet Peering
# -
data "azurerm_virtual_network" "destination" {
  for_each            = var.vnet_peering
  name                = each.value["destination_vnet_name"]
  resource_group_name = each.value["destination_vnet_rg"]
  depends_on          = [azurerm_virtual_network.this]
}

data "azurerm_virtual_network" "source" {
  for_each            = var.vnet_peering
  name                = each.value["source_vnet_name"]
  resource_group_name = each.value["rg_name"]
  depends_on          = [azurerm_virtual_network.this]
}

# locals {
#   remote_vnet_id_map = {
#     for k, v in data.azurerm_virtual_network.destination :
#     v.name => v.id
#   }
#   source_vnet_id_map = {
#     for k, v in data.azurerm_virtual_network.source :
#     v.name => v.id
#   }
# }

resource "azurerm_virtual_network_peering" "source_to_destination" {
  for_each                     = var.vnet_peering
  name                         = "${each.value["source_vnet_name"]}-to-${each.value["destination_vnet_name"]}"
  virtual_network_name         = each.value["source_vnet_name"]
  remote_virtual_network_id    = data.azurerm_virtual_network.destination[each.key].id # lookup(local.remote_vnet_id_map, each.value["destination_vnet_name"], null)
  resource_group_name          = each.value["rg_name"]
  allow_virtual_network_access = coalesce(lookup(each.value, "allow_virtual_network_access"), true)
  allow_forwarded_traffic      = coalesce(lookup(each.value, "allow_forwarded_traffic"), true)
  allow_gateway_transit        = coalesce(lookup(each.value, "allow_gateway_transit"), false)
  use_remote_gateways          = coalesce(lookup(each.value, "use_remote_gateways"), false)
  depends_on                   = [azurerm_virtual_network.this]

  lifecycle {
    ignore_changes = [remote_virtual_network_id]
  }
}

resource "azurerm_virtual_network_peering" "destination_to_source" {
  for_each                     = var.vnet_peering
  name                         = "${each.value["destination_vnet_name"]}-to-${each.value["source_vnet_name"]}"
  remote_virtual_network_id    = data.azurerm_virtual_network.source[each.key].id #lookup(local.source_vnet_id_map, each.value["source_vnet_name"], null)
  resource_group_name          = each.value["destination_vnet_rg"]
  virtual_network_name         = each.value["destination_vnet_name"]
  allow_forwarded_traffic      = coalesce(lookup(each.value, "allow_forwarded_traffic"), true) #attempting to solve for when people enter null
  allow_virtual_network_access = coalesce(lookup(each.value, "allow_virtual_network_access"), true)
  allow_gateway_transit        = coalesce(lookup(each.value, "allow_gateway_transit"), false)
  use_remote_gateways          = coalesce(lookup(each.value, "use_remote_gateways"), false)
  depends_on                   = [azurerm_virtual_network.this]
}

# -
# - Subnet
# -
resource "azurerm_subnet" "this" {
  for_each                                       = var.subnets
  name                                           = each.value["name"]
  resource_group_name                            = each.value["rg_name"]
  address_prefixes                               = each.value["address_prefixes"]
  service_endpoints                              = lookup(each.value, "service_endpoints", null)    #https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet
  enforce_private_link_endpoint_network_policies = coalesce(lookup(each.value, "pe_enable"), false) #setting these two to true will Disable the policy, False will enable the policy
  enforce_private_link_service_network_policies  = coalesce(lookup(each.value, "pe_enable"), false)
  virtual_network_name                           = each.value["vnet_name"]

  dynamic "delegation" {
    for_each = coalesce(lookup(each.value, "delegation"), [])
    content {
      name = lookup(delegation.value, "name", null)
      dynamic "service_delegation" {
        for_each = coalesce(lookup(delegation.value, "service_delegation"), [])
        content {
          name    = lookup(service_delegation.value, "name", null)
          actions = lookup(service_delegation.value, "actions", null)
        }
      }
    }
  }

  depends_on = [azurerm_virtual_network.this]
}


variable "private_dns_zones" {
  description = "A list of Private DNS Zones and their properties." # https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_zone
  type = list(object({
    name                = string
    resource_group_name = string
    tags                = map(string)
    soa_record = object({
      email        = string
      expire_time  = number
      minimum_ttl  = number
      refresh_time = number
      retry_time   = number
      ttl          = number
    })
  }))
}

resource "azurerm_private_dns_zone" "this" {
  for_each            = { for n in var.private_dns_zones : "${n.name}" => n } #name of private dns zone is unique
  name                = each.value.name
  resource_group_name = each.value.resource_group_name
  tags                = merge(data.azurerm_resource_group.this[each.value.resource_group_name].tags, each.value.tags)
  soa_record {
    email        = each.value.soa_record.email
    expire_time  = each.value.soa_record.expire_time
    minimum_ttl  = each.value.soa_record.minimum_ttl
    refresh_time = each.value.soa_record.refresh_time
    retry_time   = each.value.soa_record.retry_time
    ttl          = each.value.soa_record.ttl
  }
}