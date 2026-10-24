# Owner: full control on FS01, including role assignments
resource "azurerm_role_assignment" "sysadmin_owner" {
  scope                = data.azurerm_virtual_machine.fs01.id
  role_definition_name = "Owner"
  principal_id         = var.sysadmin_object_id
}

# Virtual Machine Contributor: manage the VM, but not RBAC and not the network or storage it uses
resource "azurerm_role_assignment" "supporttech_vm_contributor" {
  scope                = data.azurerm_virtual_machine.fs01.id
  role_definition_name = "Virtual Machine Contributor"
  principal_id         = var.support_user_object_id
}

# Reader: view FS01 only, no actions
resource "azurerm_role_assignment" "auditor_reader" {
  scope                = data.azurerm_virtual_machine.fs01.id
  role_definition_name = "Reader"
  principal_id         = var.auditor_object_id
}
