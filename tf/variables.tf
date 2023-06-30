variable "resource_group_name" {
  default     = "caenguidanos"
  description = "Resource group name in your Azure subscription."
}

variable "resource_group_location" {
  default     = "francecentral"
  description = "Location of the resource group in your Azure subscription."
}

variable "http_server_name" {
  default     = "api"
  description = "Name of the HTTP Server"
}

variable "http_server_port" {
  default     = 8080
  description = "Exposed PORT of the HTTP Server"
}

variable "mysql_admin_login" {
  default     = "admin_1234"
  sensitive   = true
  description = "MySQL Administrator Login"
}

variable "mysql_admin_password" {
  default     = "ox62212&UTfO!"
  sensitive   = true
  description = "MySQL Administrator Password"
}

variable "mysql_database" {
  default     = "super"
  description = "MySQL database name"
}

variable "mysql_sku" {
  default     = "B_Standard_B1s"
  description = "MySQL server SKU name"
}

variable "mysql_storage" {
  default     = 5 * 1024
  description = "MySQL storage capacity in MB"
}

variable "mysql_version" {
  default     = "8.0"
  description = "MySQL server version"
}

variable "static_app_domain" {
  default     = "beta.caenguidanos.com"
  description = "Static App custom domain"
}

variable "storage_container" {
  default     = "caenguidanos"
  description = "Storage Account Container name"
}
