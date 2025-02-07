# ================================
# User Input Variables with Defaults
# ================================
variable "subscription_id" {
  description = "Azure Subscription ID"
  type        = string
}

variable "restricted_subscription_id" {
  description = "Subscription ID allowed to access the Private Link Service"
  type        = string
}

variable "admin_public_ip" {
  description = "Your Public IP to allow SSH access"
  type        = string
}

variable "base_name" {
  description = "Base name for all resources"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "resource_group_name" {
  description = "Azure Resource Group same as your vNet"
  type        = string
}

variable "vnet_name" {
  description = "Virtual Network Name"
  type        = string
}

variable "subnet_name" {
  description = "Subnet Name"
  type        = string
}

variable "admin_username" {
  description = "Admin username for the VM"
  type        = string
}

variable "admin_password" {
  description = "Admin password for the Windows VM"
  type        = string
  sensitive   = true
}

variable "vm_size" {
  description = "Azure VM size"
  type        = string
}

# OS Type Selection (Linux or Windows)
variable "vm_os_type" {
  description = "Operating system type (linux or windows)"
  type        = string
  validation {
    condition     = contains(["linux", "windows"], var.vm_os_type)
    error_message = "Valid values are 'linux' or 'windows'."
  }
}

variable "vm_image" {
  description = "VM Image Reference (Publisher, Offer, SKU, Version)"
  type = object({
    publisher = string
    offer     = string
    sku       = string
    version   = string
  })
}

variable "ip_forwarding_targets" {
  description = "List of target IPs and ports for forwarding"
  type = list(object({
    ip   = string
    port = number
  }))
}
