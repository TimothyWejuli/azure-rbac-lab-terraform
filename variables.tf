variable "resource_group_name" {
  description = "Must match the NTFS lab exactly (case-sensitive)."
  type        = string
  default     = "RG-FileServerLab"
}

variable "vm_name" {
  description = "Must match the NTFS lab exactly (case-sensitive)."
  type        = string
  default     = "FS01"
}

variable "location" {
  type    = string
  default = "Central US"
}

variable "sysadmin_object_id" {
  description = "Entra ID Object ID for SysAdmin - receives Owner on FS01."
  type        = string
}

variable "support_user_object_id" {
  description = "Entra ID Object ID for SupportTech - receives Virtual Machine Contributor on FS01."
  type        = string
}

variable "auditor_object_id" {
  description = "Entra ID Object ID for Auditor - receives Reader on FS01."
  type        = string
}
