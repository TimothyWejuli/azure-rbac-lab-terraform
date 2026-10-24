# Read the NTFS lab's resource group (read-only)
data "azurerm_resource_group" "lab" {
  name = var.resource_group_name
}

# Read FS01 by name to get its full resource ID.
# Scoping to the VM resource ID limits each role to FS01 only.
# Scoping to the resource group ID would also cover DC01 and CLIENT01.
data "azurerm_virtual_machine" "fs01" {
  name                = var.vm_name
  resource_group_name = data.azurerm_resource_group.lab.name
}
