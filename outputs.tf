output "aca_url" {
  value = azurerm_container_app.juice_shop.latest_revision_fqdn
}

output "acr_login_server" {
  value = azurerm_container_registry.acr.login_server
}