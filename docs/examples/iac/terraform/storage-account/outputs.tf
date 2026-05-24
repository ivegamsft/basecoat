output "storage_account_id" {
  description = "Resource ID of the storage account."
  value       = azurerm_storage_account.example.id
}

output "storage_account_name" {
  description = "Name of the storage account."
  value       = azurerm_storage_account.example.name
}
