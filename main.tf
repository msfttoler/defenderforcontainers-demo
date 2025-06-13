provider "azurerm" {
  features {}
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
  location                     = azurerm_resource_group.demo_rg.location
  revision_mode                = "Single"

  registry {
    server   = azurerm_container_registry.acr.login_server
    username = azurerm_container_registry.acr.admin_username
    password = azurerm_container_registry.acr.admin_password
  }

  template {
    container {
      name   = "juice"
      image  = "${azurerm_container_registry.acr.login_server}/juice-shop:latest"
      cpu    = 0.5
      memory = "1.0Gi"

      probes {
        type     = "Liveness"
        http_get {
          path = "/"
          port = 3000
        }
        initial_delay_seconds = 10
        period_seconds        = 30
      }
    }

    scale {
      min_replicas = 1
      max_replicas = 3
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

resource "azurerm_monitor_diagnostic_setting" "aca_diag" {
  name               = "aca-log-forwarding"
  target_resource_id = azurerm_container_app.juice_shop.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id

  log {
    category = "ContainerAppConsoleLogs"
    enabled  = true

    retention_policy {
      enabled = false
    }
  }

  metric {
    category = "AllMetrics"
    enabled  = true

    retention_policy {
      enabled = false
    }
  }
}

# Defender for Containers (Agentless + ACR scanning)
resource "azurerm_security_center_subscription_pricing" "aca_defender" {
  tier          = "Standard"
  resource_type = "AppServices"
}

resource "azurerm_security_center_subscription_pricing" "acr_defender" {
  tier          = "Standard"
  resource_type = "ContainerRegistry"
}

resource "azurerm_security_center_auto_provisioning" "autoprov" {
  auto_provision = "On"
}

# ✅ Sample Azure Policy: Only allow images from ACR
resource "azurerm_policy_definition" "deny_external_images" {
  name         = "deny-external-container-images"
  policy_type  = "Custom"
  mode         = "Indexed"
  display_name = "Deny external container images"
  description  = "Only allow container images from approved Azure Container Registries."

  policy_rule = jsonencode({
    "if": {
      "allOf": [
        {
          "field": "type",
          "equals": "Microsoft.App/containerApps"
        },
        {
          "field": "Microsoft.App/containerApps/template/containers/image",
          "notLike": "${azurerm_container_registry.acr.login_server}/*"
        }
      ]
    },
    "then": {
      "effect": "deny"
    }
  })

  metadata = jsonencode({
    "category" : "Container Apps"
  })
}

resource "azurerm_policy_assignment" "enforce_internal_images" {
  name                 = "only-internal-images"
  scope                = azurerm_resource_group.demo_rg.id
  policy_definition_id = azurerm_policy_definition.deny_external_images.id
  description          = "Only allow images from internal Azure Container Registry"
  display_name         = "Restrict external container images"
}