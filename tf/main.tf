resource "azurerm_resource_group" "default" {
  name     = var.resource_group_name
  location = var.resource_group_location
}

resource "azurerm_container_registry" "default" {
  name                = "${var.resource_group_name}Registry"
  resource_group_name = azurerm_resource_group.default.name
  location            = azurerm_resource_group.default.location
  sku                 = "Basic"
  admin_enabled       = true
}


resource "azurerm_service_plan" "default" {
  name                = "${azurerm_resource_group.default.name}ServicePlan"
  location            = azurerm_resource_group.default.location
  resource_group_name = azurerm_resource_group.default.name
  os_type             = "Linux"
  sku_name            = "S1"
  worker_count        = 2
}

resource "azurerm_linux_web_app" "http_server" {
  name                = "${var.resource_group_name}-${var.http_server_name}"
  resource_group_name = azurerm_resource_group.default.name
  location            = azurerm_service_plan.default.location
  service_plan_id     = azurerm_service_plan.default.id
  https_only          = true

  identity {
    type = "SystemAssigned"
  }

  site_config {
    always_on                         = true
    health_check_path                 = "/healthz"
    health_check_eviction_time_in_min = 2

    application_stack {
      docker_image     = "${azurerm_container_registry.default.login_server}/${var.resource_group_name}-${var.http_server_name}"
      docker_image_tag = "release"
    }
  }

  app_settings = {
    WEBSITES_PORT = var.http_server_port

    RUST_LOG = "debug"

    DATABASE_HOST = azurerm_mariadb_server.default.fqdn
    DATABASE_USER = "${var.mariadb_admin_user}@${azurerm_mariadb_server.default.name}"
    DATABASE_PASS = var.mariadb_admin_password
    DATABASE_NAME = azurerm_resource_group.default.name

    DOCKER_REGISTRY_SERVER_URL      = "https://${azurerm_container_registry.default.login_server}"
    DOCKER_REGISTRY_SERVER_USERNAME = azurerm_container_registry.default.admin_username
    DOCKER_REGISTRY_SERVER_PASSWORD = azurerm_container_registry.default.admin_password

    AZURE_RESOURCE_GROUP_NAME = var.resource_group_name
  }
}

resource "azurerm_container_registry_webhook" "http_server" {
  name                = "${var.resource_group_name}HttpServerWebHook"
  resource_group_name = azurerm_resource_group.default.name
  registry_name       = azurerm_container_registry.default.name
  location            = azurerm_resource_group.default.location


  service_uri = "https://${azurerm_linux_web_app.http_server.site_credential[0].name}:${azurerm_linux_web_app.http_server.site_credential[0].password}@${azurerm_linux_web_app.http_server.name}.scm.azurewebsites.net/api/registry/webhook"
  status      = "enabled"
  scope       = "${azurerm_linux_web_app.http_server.name}:release"
  actions     = ["push"]
  custom_headers = {
    "Content-Type" = "application/json"
  }
}

resource "azurerm_linux_web_app_slot" "http_server_slot" {
  name           = "${azurerm_linux_web_app.http_server.name}-staging"
  app_service_id = azurerm_linux_web_app.http_server.id
  https_only     = true

  site_config {}
}

resource "azurerm_role_assignment" "acr" {
  scope                = azurerm_service_plan.default.id
  role_definition_name = "Reader"
  principal_id         = azurerm_linux_web_app.http_server.identity[0].principal_id
}

resource "azurerm_mariadb_server" "default" {
  name                = "${azurerm_resource_group.default.name}-mariadb-server"
  location            = azurerm_resource_group.default.location
  resource_group_name = azurerm_resource_group.default.name

  sku_name = "B_Gen5_1"

  storage_mb                       = 5 * 1024
  backup_retention_days            = 7
  geo_redundant_backup_enabled     = false
  version                          = "10.3"
  auto_grow_enabled                = true
  ssl_enforcement_enabled          = false
  ssl_minimal_tls_version_enforced = "TLSEnforcementDisabled"

  administrator_login          = var.mariadb_admin_user
  administrator_login_password = var.mariadb_admin_password
}

resource "azurerm_mariadb_database" "default" {
  name                = azurerm_resource_group.default.name
  resource_group_name = azurerm_resource_group.default.name
  server_name         = azurerm_mariadb_server.default.name
  charset             = "utf8mb4"
  collation           = "utf8mb4_unicode_520_ci"
}

resource "azurerm_mariadb_firewall_rule" "default" {
  for_each = toset(azurerm_linux_web_app.http_server.outbound_ip_address_list)

  name                = "${azurerm_linux_web_app.http_server.name}-${index(azurerm_linux_web_app.http_server.outbound_ip_address_list, each.key)}"
  resource_group_name = azurerm_resource_group.default.name
  server_name         = azurerm_mariadb_server.default.name
  start_ip_address    = each.key
  end_ip_address      = each.key
}
