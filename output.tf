# ================================
# Outputs (Ordered)
# ================================

# 1️⃣ Private Link Service Alias
output "private_link_service_alias" {
  description = "Alias of the Private Link Service"
  value       = azurerm_private_link_service.pls.alias
}

# 2️⃣ Load Balancer Name
output "load_balancer_name" {
  description = "Name of the Internal Load Balancer"
  value       = azurerm_lb.internal_lb.name
}

# 3️⃣ Virtual Machine Name
output "vm_name" {
  description = "Virtual Machine Name"
  value       = var.vm_os_type == "linux" ? azurerm_linux_virtual_machine.vm[0].name : azurerm_windows_virtual_machine.vm[0].name
  depends_on  = [azurerm_linux_virtual_machine.vm, azurerm_windows_virtual_machine.vm]
}

# 4️⃣ Virtual Machine Public IP
output "vm_public_ip" {
  description = "Public IP Address of the Virtual Machine"
  value       = var.vm_os_type == "linux" ? azurerm_linux_virtual_machine.vm[0].public_ip_address : azurerm_windows_virtual_machine.vm[0].public_ip_address
  depends_on  = [azurerm_linux_virtual_machine.vm, azurerm_windows_virtual_machine.vm]
}

# 5️⃣ SSH Private Key for Linux or a message for Windows
output "ssh_private_key" {
  description = "SSH Private Key for Linux VM or Message for Windows"
  value       = var.vm_os_type == "linux" ? azapi_resource_action.ssh_public_key_gen[0].output.privateKey : "SSH Key not applicable for Windows VM, use UserID & Password"
  depends_on  = [azapi_resource_action.ssh_public_key_gen]
}

# 6️⃣ SSH Public Key for Linux or Message for Windows
output "ssh_public_key" {
  description = "SSH Public Key for Linux VM"
  value       = var.vm_os_type == "linux" ? azapi_resource_action.ssh_public_key_gen[0].output.publicKey : "SSH Key not applicable for Windows VM, use UserID & Password"
  depends_on  = [azapi_resource_action.ssh_public_key_gen]
}

# 7️⃣ Separate Sensitive SSH Key Output (Only for Linux)
output "ssh_private_key_sensitive" {
  description = "Sensitive SSH Private Key for Linux (Hidden in Logs)"
  value       = var.vm_os_type == "linux" ? azapi_resource_action.ssh_public_key_gen[0].output.privateKey : null
  sensitive   = true
  depends_on  = [azapi_resource_action.ssh_public_key_gen]
}
