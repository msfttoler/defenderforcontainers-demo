terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.50.0"
    }
  }
  required_version = ">= 1.4"
}

provider "azurerm" {
  features {}
  subscription_id = "e15e403f-7ca0-4fa6-9c9b-e780f664db5b"
}

variable "location" {
  default = "eastus"
}

resource "azurerm_resource_group" "demo_rg" {
  name     = "aca-defender-demo-rg"
  location = var.location
}

resource "azurerm_log_analytics_workspace" "law" {
  name                = "aca-demo-law"
  location            = azurerm_resource_group.demo_rg.location
  resource_group_name = azurerm_resource_group.demo_rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_container_registry" "acr" {
  name                = "acajuicedemoacr"
  location            = azurerm_resource_group.demo_rg.location
  resource_group_name = azurerm_resource_group.demo_rg.name
  sku                 = "Basic"
  admin_enabled       = true
}

resource "azurerm_container_app_environment" "aca_env" {
  name                       = "aca-defender-demo-env"
  location                   = azurerm_resource_group.demo_rg.location
  resource_group_name        = azurerm_resource_group.demo_rg.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id
}

resource "azurerm_container_app" "juice_shop" {
  name                         = "owasp-juice-shop"
  container_app_environment_id = azurerm_container_app_environment.aca_env.id
  resource_group_name          = azurerm_resource_group.demo_rg.name
  revision_mode                = "Single"

  template {
    container {
      name   = "juice"
      image  = "bkimminich/juice-shop:latest"
      cpu    = 0.5
      memory = "1.0Gi"
    }
  }

  ingress {
    external_enabled = true
    target_port      = 3000
    transport        = "auto"

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }
}

resource "azurerm_application_insights_workbook" "container_vuln_workbook" {
  name                = "f7b9f3ab-7d58-4a12-8b4b-aca111111001"
  resource_group_name = azurerm_resource_group.demo_rg.name
  location            = azurerm_resource_group.demo_rg.location
  display_name        = "Container Image Vulnerability Overview"
  category            = "workbook"
  data_json           = file("${path.module}/container_image_vulnerability_overview.json")
}

resource "azurerm_application_insights_workbook" "aca_runtime_workbook" {
  name                = "c3d2a9b0-19f2-4ad7-90fe-aca111111002"
  resource_group_name = azurerm_resource_group.demo_rg.name
  location            = azurerm_resource_group.demo_rg.location
  display_name        = "ACA Runtime Threat Detection"
  category            = "workbook"
  data_json           = file("${path.module}/aca_runtime_threat_detection.json")
}

output "aca_url" {
  value = azurerm_container_app.juice_shop.latest_revision_fqdn
}

output "acr_login_server" {
  value = azurerm_container_registry.acr.login_server
}