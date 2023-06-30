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
    # APP VARS
    RUST_LOG                  = "debug"
    DATABASE_HOST             = azurerm_mysql_flexible_server.default.fqdn
    DATABASE_USER             = "${var.mariadb_admin_user}@${azurerm_mariadb_server.default.name}"
    DATABASE_PASS             = var.mysql_admin_password
    DATABASE_NAME             = azurerm_resource_group.default.name
    AZURE_RESOURCE_GROUP_NAME = var.resource_group_name

    # INFRA VARS
    WEBSITES_PORT                   = var.http_server_port
    DOCKER_REGISTRY_SERVER_URL      = "https://${azurerm_container_registry.default.login_server}"
    DOCKER_REGISTRY_SERVER_USERNAME = azurerm_container_registry.default.admin_username
    DOCKER_REGISTRY_SERVER_PASSWORD = azurerm_container_registry.default.admin_password
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

resource "azurerm_mysql_flexible_server" "default" {
  name                             = "${azurerm_resource_group.default.name}-mysql-server"
  resource_group_name              = azurerm_resource_group.default.name
  location                         = azurerm_resource_group.default.location
  administrator_login              = var.mysql_admin_login
  administrator_password           = var.mysql_admin_password
  sku_name                         = var.mysql_sku
  storage_mb                       = var.mysql_storage
  version                          = var.mysql_version
  auto_grow_enabled                = true
  backup_retention_days            = 7
  geo_redundant_backup_enabled     = true
  public_network_access_enabled    = true
  ssl_enforcement_enabled          = false
  ssl_minimal_tls_version_enforced = "TLSEnforcementDisabled"
}

resource "azurerm_mysql_flexible_database" "default" {
  name                = var.mysql_database
  resource_group_name = azurerm_resource_group.default.name
  server_name         = azurerm_mysql_flexible_server.default.name
  charset             = "utf8"
  collation           = "utf8_unicode_ci"
}

resource "azurerm_static_site" "default" {
  name                = "${var.resource_group_name}-static"
  resource_group_name = azurerm_resource_group.default.name
  location            = azurerm_resource_group.default.location
}

resource "azurerm_static_site_custom_domain" "example" {
  static_site_id  = azurerm_static_site.default.id
  domain_name     = var.static_app_domain
  validation_type = "cname-delegation"
}

resource "azurerm_storage_account" "default" {
  name                     = "${var.resource_group_name}-storage-account"
  resource_group_name      = azurerm_resource_group.default.name
  location                 = azurerm_resource_group.default.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "default" {
  name                  = var.storage_container
  storage_account_name  = azurerm_storage_account.default.name
  container_access_type = "private"
}

# AFTER APPLY
resource "azurerm_mysql_firewall_rule" "default" {
  for_each = toset(azurerm_linux_web_app.http_server.outbound_ip_address_list)

  name                = "${azurerm_linux_web_app.http_server.name}-${index(azurerm_linux_web_app.http_server.outbound_ip_address_list, each.key)}"
  resource_group_name = azurerm_resource_group.default.name
  server_name         = azurerm_mysql_flexible_server.default.name
  start_ip_address    = each.key
  end_ip_address      = each.key
}
