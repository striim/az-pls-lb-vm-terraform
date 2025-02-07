# ================================
# Generate SSH Key Resource (Only for Linux)
# ================================
resource "random_pet" "ssh_key_name" {
  count     = var.vm_os_type == "linux" ? 1 : 0                     # ✅ Only run when Linux is selected
  prefix    = var.base_name
  separator = ""
}

resource "azapi_resource_action" "ssh_public_key_gen" {
  count      = var.vm_os_type == "linux" ? 1 : 0                    # ✅ Only run when Linux is selected
  type        = "Microsoft.Compute/sshPublicKeys@2022-11-01"
  resource_id = azapi_resource.ssh_public_key[0].id
  action      = "generateKeyPair"
  method      = "POST"

  response_export_values = ["publicKey", "privateKey"]
}

resource "azapi_resource" "ssh_public_key" {
  count     = var.vm_os_type == "linux" ? 1 : 0                     # ✅ Only run when Linux is selected
  type      = "Microsoft.Compute/sshPublicKeys@2022-11-01"
  name      = "${var.base_name}-ssh-key"
  location  = data.azurerm_resource_group.rg.location
  parent_id = data.azurerm_resource_group.rg.id
}
