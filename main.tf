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

variable "list" {
  type = list(object({
    name     = string
    location = string
  }))
  default = [
    {
      name     = "rg-list-01"
      location = "westeurope"
    },
    {
      name     = "rg-list-02"
      location = "westeurope"
    }
  ]
}

variable "list2" {
  type = list(object({
    name     = string
    location = string
  }))
  default = [
    {
      name     = "rg-list-03"
      location = "westeurope"
    },
    {
      name     = "rg-list-04"
      location = "westeurope"
    }
  ]
}

variable "for_each_map" {
  type = map(object({
    name     = string
    location = string
  }))
  default = {
    rg1 = {
      name     = "rg-map-01"
      location = "westeurope"
    }
    rg2 = {
      name     = "rg-map-02"
      location = "westeurope"
    }
  }
}

variable "for_each_othermap" {
  type = map(object({
    name     = string
    location = string
  }))
  default = {
    rg1 = {
      name     = "rg-map-03"
      location = "westeurope"
    }
    rg2 = {
      name     = "rg-map-04"
      location = "westeurope"
    }
  }
}

variable "for_each_test_map" {
  type = map(object({
    name     = string
    location = string
  }))
  default = {
    rg1 = {
      name     = "rg-map-05"
      location = "westeurope"
    }
    rg2 = {
      name     = "rg-map-06"
      location = "westeurope"
    }
  }
}

locals {
  list2map = {
    for n in var.list2 :
    n.name => {
      name     = n.name
      location = n.location
    }
  }
}

resource "azurerm_resource_group" "map-for_each-default-key" {
  # just use a map
  for_each = var.for_each_map
  name     = each.value.name
  location = each.value.location
}

resource "azurerm_resource_group" "map-for_each-default-key-2" {
  # use a map as input and transform (inline) to map with the default key
  for_each = {
    for k, v in var.for_each_othermap : "${k}" => v
  }
  name     = each.value.name
  location = each.value.location
}

resource "azurerm_resource_group" "map-for_each-name-key" {
  # use a map as input and transform (inline) to map with name as key
  for_each = {
    for t in var.for_each_othermap : "${t.name}" => t
  }
  name     = each.value.name
  location = each.value.location
}

resource "azurerm_resource_group" "list-for_each-name-key" {
  # use a list as input and transform (inline) to map with name as key
  for_each = {
    for t in var.list : "${t.name}" => t
  }
  name     = each.value.name
  location = each.value.location
}

resource "azurerm_resource_group" "list-for_each-local-var" {
  # use a local map as input with a self-defined key
  for_each = local.list2map
  name     = each.value.name
  location = each.value.location
}