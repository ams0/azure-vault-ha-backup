variable "resource_group" {
  description = "The existing resource group to hold all resources created by this module"
  default     = ""
}
variable "retention" {
  description = "Retention period for snapshots in days"
  default     = "7"
}
variable "tag" {
  description = "Which tag to consider when looking for disks to snapshot"
  default     = "Snapshot"
}

variable "frequency" {
  description = "Snapshot frequency"
  default     = "Hour"
}
