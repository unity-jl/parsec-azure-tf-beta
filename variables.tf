variable "resource_group_location" {
  type        = string
  default     = "southcentralus"
  description = "Location of the resource group."
}

variable "relay_quantity" {
  type        = number
  default     = 2
  description = "Quantity of relay servers (HPR)"
}

variable "desktop_quantity" {
  type        = number
  default     = 1
  description = "Quantity of desktops/workstations"
}

variable "desktop_vm_sku" {
  type        = string
  default     = "Standard_NC4as_T4_v3"
  description = "VM series for user desktops/workstations"
}

variable "relay_vm_sku" {
  type        = string
  default     = "Standard_B2ms"
  description = "VM series for relay servers (HPR)"
}

variable "relay_os_sku" {
  type        = string
  default     = ""
  description = ""
}

variable "relay_image_sku" {
  type        = string
  default     = ""
  description = ""
}

variable "username" {
  type        = string
  default     = "" #UPDATE DEFAULT USERNAME HERE
  description = "The username for the local account that will be created on the new VM."
}

variable "publickey1" {
    type        = string
    default     = "" #UPDATE HPR SSH KEY HERE - Paste raw public key data
    description = "public SSH key 1"
}

variable "resource_group_name" {
  type        = string
  default     = "parsec-tf-rg"
  description = "Name of the resource group."
}

variable "public_nsg_name" {
  type        = string
  default     = "public-nsg"
  description = "Name of the public NSG."
}

variable "private_nsg_name" {
  type        = string
  default     = "private-nsg"
  description = "Name of the private NSG."
}

variable "relay_vmss_name" {
  type        = string
  default     = "hprvmss"
  description = "Name of the relay server (HPR) Scale Set."
}

variable "desktop_vmss_name" {
  type        = string
  default     = "w10vmss"
  description = "Name of the desktop/workstation Scale Set."
}