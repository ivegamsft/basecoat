variable "location" {
  type        = string
  description = "Azure region for the resources."
}

variable "resource_group_name" {
  type        = string
  description = "Existing or target resource group name."
}

variable "storage_account_name" {
  type        = string
  description = "Globally unique storage account name."
}

variable "tags" {
  type        = map(string)
  description = "Resource tags applied to all supported resources."
  default = {
    environment = "dev"
    owner       = "platform"
  }
}
