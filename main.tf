# ================================
# Resource Group Reference
# ================================
data "azurerm_resource_group" "rg" {
  name = var.resource_group_name
}

# ================================
# Virtual Network & Subnet Reference
# ================================
data "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  resource_group_name = var.resource_group_name
}

data "azurerm_subnet" "subnet" {
  name                 = var.subnet_name
  virtual_network_name = data.azurerm_virtual_network.vnet.name
  resource_group_name  = var.resource_group_name
}

# ================================
# Public IP for VM
# ================================
resource "azurerm_public_ip" "vm_public_ip" {
  name                = "${var.base_name}-public-ip"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# ================================
# Create Security Group for VM
# ================================
resource "azurerm_network_security_group" "vm_nsg" {
  name                = "${var.base_name}-nsg"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
}

# Allow SSH or RDP based on OS Type
resource "azurerm_network_security_rule" "allow_remote_access" {
  name                        = var.vm_os_type == "linux" ? "AllowSSH" : "AllowRDP"
  priority                    = 1022
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = var.vm_os_type == "linux" ? "22" : "3389"
  source_address_prefix       = var.admin_public_ip
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.vm_nsg.name
}

# Associate Security Group with VM Network Interface
resource "azurerm_network_interface_security_group_association" "vm_nic_nsg" {
  network_interface_id      = azurerm_network_interface.vm_nic.id
  network_security_group_id = azurerm_network_security_group.vm_nsg.id
}

# ================================
# Create Network Interface for VM
# ================================
resource "azurerm_network_interface" "vm_nic" {
  name                = "${var.base_name}-nic"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name


  ip_configuration {
    name                          = "internal"
    subnet_id                     = data.azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm_public_ip.id  # ✅ Attach Public IP
  }

  lifecycle {
    create_before_destroy = true                                        # ✅ Ensure NIC is deleted when VM is deleted
  }
}

# ================================
# Associate VM NIC with Load Balancer NAT Rules
# ================================
resource "azurerm_network_interface_nat_rule_association" "vm_nic_nat_assoc" {
  count                = length(var.ip_forwarding_targets)
  network_interface_id = azurerm_network_interface.vm_nic.id
  ip_configuration_name = "internal"
  nat_rule_id          = azurerm_lb_nat_rule.nat_rules[count.index].id
}

# ================================
# VM User Data (Cloud-Init-Linux Script)
# ================================
data "template_file" "cloud_init_linux" {
  template = <<EOF
#!/bin/bash

# Enable IP forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward
sysctl -w net.ipv4.ip_forward=1

# Get the primary private IP of the VM (default interface)
SOURCE_IP=$(ip route get 1 | awk '{print $7}')

%{for rule in var.ip_forwarding_targets}
# Set up forwarding rule for ${rule.ip}:${rule.port}
iptables -t nat -A PREROUTING -p tcp --dport ${rule.port} -j DNAT --to-destination ${rule.ip}:${rule.port}
iptables -t nat -A POSTROUTING -p tcp -d ${rule.ip} --dport ${rule.port} -j SNAT --to-source $SOURCE_IP
%{endfor}

# Save IPTables rules
iptables-save > /etc/iptables/rules.v4

# Install iptables-persistent to keep rules after reboot
DEBIAN_FRONTEND=noninteractive apt update && apt install -y iptables-persistent
EOF
}

# ================================
# Create Ubuntu Virtual Machine
# ================================
resource "azurerm_linux_virtual_machine" "vm" {
  count               = var.vm_os_type == "linux" ? 1 : 0                   # ✅ Only deploy if Linux
  name                = "${var.base_name}-vm"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.vm_nic.id]
  size                = var.vm_size
  admin_username      = var.admin_username
  disable_password_authentication = true

  admin_ssh_key {
    username   = var.admin_username
    public_key = azapi_resource_action.ssh_public_key_gen[0].output.publicKey
  }

  os_disk {
    name                      = "${var.base_name}-osdisk"
    caching                   = "ReadWrite"
    storage_account_type       = "Premium_LRS"
  }

  source_image_reference {
    publisher = var.vm_image.publisher
    offer     = var.vm_image.offer
    sku       = var.vm_image.sku
    version   = var.vm_image.version
  }

  secure_boot_enabled = true
  vtpm_enabled        = true

  # Run the IP forwarding & IPTables setup script on startup
  custom_data = base64encode(data.template_file.cloud_init_linux.rendered)

}

# ================================
# Create Windows Virtual Machine
# ================================
resource "azurerm_windows_virtual_machine" "vm" {
  count               = var.vm_os_type == "windows" ? 1 : 0                      # ✅  Only deploy if Windows
  name                = "${var.base_name}-vm"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.vm_nic.id]
  size                = var.vm_size
  admin_username      = var.admin_username
  admin_password      = var.admin_password                                       # ✅  Windows requires a password

  # Ensure the computer name is at most 15 characters
  computer_name       = substr("${var.base_name}-vm", 0, 15)

  os_disk {
    name                      = "${var.base_name}-osdisk"
    caching                   = "ReadWrite"
    storage_account_type       = "Premium_LRS"
  }

  source_image_reference {
    publisher = var.vm_image.publisher
    offer     = var.vm_image.offer
    sku       = var.vm_image.sku
    version   = var.vm_image.version
  }

  secure_boot_enabled = true
  vtpm_enabled        = true
  enable_automatic_updates = true
  provision_vm_agent       = true

  # Windows-specific User Data for IP Forwarding (netsh commands)
  # custom_data = base64encode(data.template_file.cloud_init_windows.rendered)
}

# ================================
# Create Storage Account for VM Scripts
# ================================
resource "azurerm_storage_account" "vm_scripts" {
  count = var.vm_os_type == "windows" ? 1 : 0
  name                     = substr(lower(replace(var.base_name, "-", "")), 0, 20)  
  resource_group_name      = data.azurerm_resource_group.rg.name
  location                 = data.azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "scripts" {
  count = var.vm_os_type == "windows" ? 1 : 0
  name                 = "vm-scripts"
  storage_account_id   = azurerm_storage_account.vm_scripts[0].id
  container_access_type = "blob"  # ✅ This enables public access
}

resource "azurerm_storage_blob" "config_script" {
  count = var.vm_os_type == "windows" ? 1 : 0
  name                   = "config-script.ps1"
  storage_account_name   = azurerm_storage_account.vm_scripts[0].name
  storage_container_name = azurerm_storage_container.scripts[0].name
  type                   = "Block"
  
  source_content = <<EOT
# Enable IP forwarding on Windows
Set-NetIPInterface -Forwarding Enabled -InterfaceAlias "Ethernet"

# Ensure firewall allows traffic on forwarded ports
netsh advfirewall firewall add rule name="Allow Port Forwarding" dir=in action=allow protocol=TCP localport=ANY

# Define Port Forwarding Rules
%{for rule in var.ip_forwarding_targets~}
Write-Output "Adding port forwarding rule: Listen ${rule.port} → ${rule.ip}:${rule.port}"
netsh interface portproxy add v4tov4 listenport=${rule.port} listenaddress=0.0.0.0 connectport=${rule.port} connectaddress=${rule.ip}
%{endfor~}

# Restart Services for changes to take effect
Restart-Service WinNat -Force
Restart-Service iphlpsvc -Force

# Wait before checking rules
Start-Sleep -Seconds 30

# Verify Port Proxy Rules
netsh interface portproxy show all | Out-File C:\AzureData\portproxy.log
EOT
}

# ================================
# Windows Virtual Machine Custom Script Extension
# ================================
resource "azurerm_virtual_machine_extension" "windows_vm_config" {
  count                = var.vm_os_type == "windows" ? 1 : 0
  name                 = "${var.base_name}-vm-config"
  virtual_machine_id   = azurerm_windows_virtual_machine.vm[0].id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  settings = <<SETTINGS
  {
    "fileUris": ["https://${azurerm_storage_account.vm_scripts[0].name}.blob.core.windows.net/${azurerm_storage_container.scripts[0].name}/${azurerm_storage_blob.config_script[0].name}"],
    "commandToExecute": "powershell -ExecutionPolicy Unrestricted -File config-script.ps1"
  }
  SETTINGS

  depends_on = [azurerm_storage_blob.config_script]
}

# ================================
# Internal Load Balancer
# ================================
resource "azurerm_lb" "internal_lb" {
  name                = "${var.base_name}-lb"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                          = "frontend-ip"
    subnet_id                     = data.azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

# ================================
# Load Balancer Backend Pool
# ================================
resource "azurerm_lb_backend_address_pool" "backend_pool" {
  loadbalancer_id = azurerm_lb.internal_lb.id
  name            = "${var.base_name}-backend-pool"

  depends_on = [azurerm_linux_virtual_machine.vm]                               # ✅ Ensure VM is created first
}

resource "azurerm_network_interface_backend_address_pool_association" "nic_backend_pool_assoc" {
  network_interface_id    = azurerm_network_interface.vm_nic.id
  ip_configuration_name   = "internal"  # Ensure this matches the VM's NIC IP config name
  backend_address_pool_id = azurerm_lb_backend_address_pool.backend_pool.id

  depends_on = [
    azurerm_linux_virtual_machine.vm, 
    azurerm_lb_backend_address_pool.backend_pool
  ]                                                                              # ✅ Ensure VM is created first
}

# ================================
# Health Probe for Load Balancer (Port 80)
# ================================
resource "azurerm_lb_probe" "health_probe" {
  loadbalancer_id = azurerm_lb.internal_lb.id
  name            = "${var.base_name}-health-probe"
  protocol        = "Tcp"
  port            = 80                                                            # ✅ Health check over port 80
  interval_in_seconds = 5
  number_of_probes    = 2
}

# ================================
# Load Balancer Rule for Port 80
# ================================
resource "azurerm_lb_rule" "lb_rule" {
  loadbalancer_id                = azurerm_lb.internal_lb.id
  name                           = "${var.base_name}-lb-rule-80"
  protocol                       = "Tcp"
  frontend_port                  = 80                                               # ✅ Traffic on port 80
  backend_port                   = 80                                               # ✅ Send to backend on port 80
  frontend_ip_configuration_name = azurerm_lb.internal_lb.frontend_ip_configuration[0].name
  backend_address_pool_ids        = [azurerm_lb_backend_address_pool.backend_pool.id]
  probe_id                        = azurerm_lb_probe.health_probe.id
}

# ================================
# Load Balancer NAT Rules for VM
# ================================
resource "azurerm_lb_nat_rule" "nat_rules" {
  count = length(var.ip_forwarding_targets)

  name                           = "${var.base_name}-nat-${count.index}"
  resource_group_name            = data.azurerm_resource_group.rg.name
  loadbalancer_id                = azurerm_lb.internal_lb.id
  protocol                       = "Tcp"
  frontend_port                  = var.ip_forwarding_targets[count.index].port
  backend_port                   = var.ip_forwarding_targets[count.index].port
  frontend_ip_configuration_name = azurerm_lb.internal_lb.frontend_ip_configuration[0].name
}

# ================================
# Private Link Service with Subscription Restriction
# ================================
resource "azurerm_private_link_service" "pls" {
  name                = "${var.base_name}-pls"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  load_balancer_frontend_ip_configuration_ids = [
    azurerm_lb.internal_lb.frontend_ip_configuration[0].id
  ]

  visibility_subscription_ids = [var.restricted_subscription_id]            # ✅ Restrict Access by Subscription

  auto_approval_subscription_ids = []                                       # ✅ Ensure manual approval is required

  nat_ip_configuration {
    name                       = "${var.base_name}-nat-ip-config"
    private_ip_address_version = "IPv4"
    subnet_id                  = data.azurerm_subnet.subnet.id
    primary                    = true
  }
}