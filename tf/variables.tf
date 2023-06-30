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

variable "mariadb_admin_user" {
  default     = "admin_1234"
  sensitive   = true
  description = "MariaDB Administrator Login"
}

variable "mariadb_admin_password" {
  default     = "ox62212&UTfO!"
  sensitive   = true
  description = "MariaDB Administrator Password"
}
