variable "ENVIRONMENT_NAME" {
    type = string
    default = "dev"
}

variable "PRODUCT_NAME" {
    type = string
}

variable "pri_location" {
    type    = string
    default = "australiaeast"
}

variable "db_sku" {
    type = string
}

variable "db_storage" {
    type = number
}

variable "db_backup_retention" {
    type = number
}

variable "db_admin_login" {
    type      = string
    sensitive = true
}

variable "db_admin_password" {
    type      = string
    sensitive = true
}

variable "db_version" {
    type = string
}

variable "app_db_name" {
    type = string
}

locals {
common_tags = tomap({
    "Product" = var.PRODUCT_NAME,
    "Environment" = var.ENVIRONMENT_NAME,
    "Deployment Method" = "Terraform"
  })
}