terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "~> 2.73.0"
    }
  }

  backend "azurerm" {
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "pri_rg" {
  name     = join("-", [var.ENVIRONMENT_NAME, var.PRODUCT_NAME, "rg"])
  location = var.pri_location
  tags     = local.common_tags
}

resource "azurerm_postgresql_server" "pg_db" {
  name                = join("-", [var.ENVIRONMENT_NAME, var.PRODUCT_NAME, "psqlserver"])
  location            = var.pri_location
  resource_group_name = azurerm_resource_group.pri_rg.name
  tags                = local.common_tags

  sku_name = var.db_sku

  storage_mb                   = var.db_storage
  backup_retention_days        = var.db_backup_retention
  geo_redundant_backup_enabled = false
  auto_grow_enabled            = false

  administrator_login          = var.db_admin_login
  administrator_login_password = var.db_admin_password
  version                      = var.db_version
  ssl_enforcement_enabled      = false
}

resource "azurerm_postgresql_firewall_rule" "pg_db_fw" {
  name                = "vm"
  resource_group_name = azurerm_resource_group.pri_rg.name
  server_name         = azurerm_postgresql_server.pg_db.name
  start_ip_address    = "20.70.203.138"
  end_ip_address      = "20.70.203.138"
}

resource "azurerm_postgresql_database" "servian_app_db" {
  name                = var.app_db_name
  resource_group_name = azurerm_resource_group.pri_rg.name
  server_name         = azurerm_postgresql_server.pg_db.name
  charset             = "UTF8"
  collation           = "English_United States.1252"
}