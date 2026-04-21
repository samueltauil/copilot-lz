variable "location" {
  description = "Azure region. Must be in the approved landing-zone list."
  type        = string
  default     = "eastus2"

  validation {
    condition     = contains(["eastus2", "centralus"], var.location)
    error_message = "Location must be one of the approved regions: eastus2, centralus."
  }
}

variable "environment" {
  description = "Environment tag: dev | test | prod."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "environment must be one of: dev, test, prod."
  }
}

variable "owner" {
  description = "Team or individual accountable for these resources."
  type        = string
  default     = "platform-infra"
}

variable "cost_center" {
  description = "Finance cost center for chargeback."
  type        = string
  default     = "CC-INFRA-001"
}

variable "data_class" {
  description = "Data classification: public | internal | confidential | phi."
  type        = string
  default     = "internal"

  validation {
    condition     = contains(["public", "internal", "confidential", "phi"], var.data_class)
    error_message = "data_class must be one of: public, internal, confidential, phi."
  }
}

variable "name_prefix" {
  description = "Short prefix used in resource names."
  type        = string
  default     = "lz"
}

locals {
  required_tags = {
    environment = var.environment
    owner       = var.owner
    cost-center = var.cost_center
    data-class  = var.data_class
    managed-by  = "terraform"
    repo        = "iac-demo"
  }
}
