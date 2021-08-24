terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 2.73.0"
    }
  }

  backend "azurerm" {
  }
}

provider "azurerm" {
  features {}
}


##############################################################
# Resources
##############################################################

resource "azurerm_resource_group" "pri_rg" {
  name     = join("-", [var.ENVIRONMENT_NAME, var.PRODUCT_NAME, "rg"])
  location = var.pri_location
  tags     = local.common_tags
}

#Virtual Network
resource "azurerm_virtual_network" "pri_vnet" {
  name                = join("-", [var.ENVIRONMENT_NAME, var.PRODUCT_NAME, "vnet"])
  address_space       = ["10.0.0.0/16"]
  location            = var.pri_location
  resource_group_name = azurerm_resource_group.pri_rg.name
}

resource "azurerm_subnet" "web_subnet" {
  name                 = join("-", [var.ENVIRONMENT_NAME, var.PRODUCT_NAME, "web", "snet"])
  resource_group_name  = azurerm_resource_group.pri_rg.name
  virtual_network_name = azurerm_virtual_network.pri_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
  service_endpoints    = ["Microsoft.Sql"]
    delegation {
    name = "web"
    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

# Container subnet used for container instance to init database.
resource "azurerm_subnet" "container_subnet" {
  name                 = join("-", [var.ENVIRONMENT_NAME, var.PRODUCT_NAME, "container", "snet"])
  resource_group_name  = azurerm_resource_group.pri_rg.name
  virtual_network_name = azurerm_virtual_network.pri_vnet.name
  address_prefixes     = ["10.0.2.0/24"]
  service_endpoints    = ["Microsoft.Sql"]
    delegation {
    name = "container_instance"
    service_delegation {
      name    = "Microsoft.ContainerInstance/containerGroups"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

resource "azurerm_network_profile" "container_network_profile" {
  name                = join("-", [var.ENVIRONMENT_NAME, var.PRODUCT_NAME, "container", "nwprofile"])
  location            = var.pri_location
  resource_group_name = azurerm_resource_group.pri_rg.name

  container_network_interface {
    name = "container_nic"

    ip_configuration {
      name      = "containeripconfig"
      subnet_id = azurerm_subnet.container_subnet.id
    }
  }
}

#Azure Postgre SQL Database
resource "azurerm_postgresql_server" "pg_server" {
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

resource "azurerm_postgresql_virtual_network_rule" "pgdb_fw_web" {
  name                                 = "allow-web-subnet"
  resource_group_name                  = azurerm_resource_group.pri_rg.name
  server_name                          = azurerm_postgresql_server.pg_server.name
  subnet_id                            = azurerm_subnet.web_subnet.id
}

resource "azurerm_postgresql_virtual_network_rule" "pgdb_fw_container" {
  name                                 = "allow-container-subnet"
  resource_group_name                  = azurerm_resource_group.pri_rg.name
  server_name                          = azurerm_postgresql_server.pg_server.name
  subnet_id                            = azurerm_subnet.container_subnet.id
}
resource "azurerm_postgresql_database" "app_db" {
  name                = var.app_db_name
  resource_group_name = azurerm_resource_group.pri_rg.name
  server_name         = azurerm_postgresql_server.pg_server.name
  charset             = "UTF8"
  collation           = "English_United States.1252"
}

# Web App service and hosting plan
resource "azurerm_app_service_plan" "web_asp" {
  name                         = join("-", [var.ENVIRONMENT_NAME, var.PRODUCT_NAME, "asp"])
  location                     = var.pri_location
  resource_group_name          = azurerm_resource_group.pri_rg.name
  kind                         = "Linux"
  reserved                     = true
  maximum_elastic_worker_count = var.asp_max_workers
  tags                         = local.common_tags
  sku {
    tier = var.asp_tier
    size = var.asp_size
  }
}

resource "azurerm_app_service" "app_service" {
  name                = join("-", [var.ENVIRONMENT_NAME, var.PRODUCT_NAME, "web"])
  location            = var.pri_location
  resource_group_name = azurerm_resource_group.pri_rg.name
  app_service_plan_id = azurerm_app_service_plan.web_asp.id
  tags                = local.common_tags

  logs {
    http_logs {
      file_system {
        retention_in_days = 1
        retention_in_mb   = 35
      }
    }
  }
  site_config {
    linux_fx_version = "DOCKER|${var.docker_image}"
    app_command_line = "serve"
  }
  app_settings = {
    "VTT_LISTENHOST"             = "0.0.0.0"
    "VTT_LISTENPORT"             = "80"
    "VTT_DBNAME"                 = var.app_db_name
    "VTT_DBPORT"                 = "5432"
    "VTT_DBHOST"                 = azurerm_postgresql_server.pg_server.fqdn
    "VTT_DBUSER"                 = join("@", [var.db_admin_login, azurerm_postgresql_server.pg_server.name])
    "VTT_DBPASSWORD"             = var.db_admin_password
    "DOCKER_REGISTRY_SERVER_URL" = "https://index.docker.io/v1"
  }


}

resource "azurerm_app_service_virtual_network_swift_connection" "vnet_integration" {
   app_service_id = azurerm_app_service.app_service.id
   subnet_id      = azurerm_subnet.web_subnet.id
}

# Container instance to initialise DB
resource "azurerm_container_group" "init_container" {
  name                = join("-", [var.ENVIRONMENT_NAME, var.PRODUCT_NAME, "init", "container"])
  location            = var.pri_location
  resource_group_name = azurerm_resource_group.pri_rg.name
  tags                = merge(local.common_tags, {"NOTE" = "Run this container to initialise the DB. Existing data will be lost"} )
  ip_address_type     = "private"
  network_profile_id  = azurerm_network_profile.container_network_profile.id
  os_type             = "Linux"
  restart_policy      = "Never" #Only run container once to init DB
  depends_on = [azurerm_postgresql_database.app_db, azurerm_postgresql_virtual_network_rule.pgdb_fw_container]

  container {
    name   = "init-container"
    image  = var.docker_image
    cpu    = "0.5"
    memory = "1.5"
    environment_variables = {
     "VTT_LISTENHOST" = "0.0.0.0"
     "VTT_LISTENPORT" = "80"
     "VTT_DBNAME"     = var.app_db_name
     "VTT_DBPORT"     = "5432"
     "VTT_DBHOST"     = azurerm_postgresql_server.pg_server.fqdn
    }
    secure_environment_variables = {
      "VTT_DBUSER"     = join("@", [var.db_admin_login, azurerm_postgresql_server.pg_server.name])
      "VTT_DBPASSWORD" = var.db_admin_password
    }
    ports {
      port     = 443
      protocol = "TCP"
    }

    commands = [ "./TechChallengeApp", "updatedb", "-s" ]

  }
}