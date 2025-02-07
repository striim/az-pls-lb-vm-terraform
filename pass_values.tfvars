subscription_id = "000000000000000000000000000000000000"                # ✅ Change this with your Azure Subscription ID
restricted_subscription_id = "000000000000000000000000000000000000"     # ✅ Change this with the striim subscription ID
admin_public_ip = "00.00.00.00/32"                                      # ✅ Change this to your actual IP for security
base_name = "striim-int"                                                # ✅ Change this name with something meaningful
location = "eastus"                                                     # ✅ Change this with your region name
resource_group_name = "your-azure-rg"                                   # ✅ Change this with your vNet resource group name
vnet_name = "your-azure-vnet"                                           # ✅ Change this with your pre-created vNet name
subnet_name = "your-subnet-name"                                        # ✅ Change this with your pre-created Subnet name
admin_username = "azureuser"                                            
admin_password = "your-secure-password"                                 # ✅ Use only If you choose Windows VM (Leave empty for security; set via environment variable)
vm_size = "Standard_D2s_v3"                                             # ✅ Change this if you want different size of the VM

##### ✅ Use below configurations block only if you want to create LINUX VM (comment this if you want windows vm)
vm_os_type = "linux"
vm_image = {
  publisher = "Canonical"
  offer     = "ubuntu-24_04-lts"
 sku       = "server"
 version   = "latest"
}

##### ✅ Use below configurations block only if you want to create WINDOWS VM (comment this if you want linux vm)
#vm_os_type = "windows"
#vm_image = {
#  publisher = "MicrosoftWindowsServer"
#  offer     = "WindowsServer"
#  sku       = "2019-datacenter-gensecond"
#  version   = "latest"
#}

# ✅ List your database IPs and Ports to create IP/Port forwarding rules
ip_forwarding_targets = [                                                   
  { ip = "192.168.00.1", port = 1433 },
  { ip = "192.168.00.2", port = 1435 },
  { ip = "192.168.00.3", port = 1438 },
  { ip = "192.168.00.4", port = 1440 }
]
