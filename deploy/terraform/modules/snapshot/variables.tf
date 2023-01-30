variable "resource_group" {
  description = "The existing resource group to hold all resources created by this module"
  default     = ""
}
variable "tag" {
  description = "Which tag to consider when looking for disks to snapshot"
  default     = "Snapshot"
}

variable "frequency" {
  description = "Snapshot frequency"
  default     = "Hour"
}
