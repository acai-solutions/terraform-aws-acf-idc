# ACAI Cloud Foundation (ACF)
# Copyright (C) 2025 ACAI GmbH
# Licensed under AGPL v3
#
# This file is part of ACAI ACF.
# Visit https://www.acai.gmbh or https://docs.acai.gmbh for more information.
# 
# For full license text, see LICENSE file in repository root.
# For commercial licensing, contact: contact@acai.gmbh


variable "permission_sets" {
  description = "A list of AWS Identity Center Permission Sets."
  type = list(object({
    name                      = string
    description               = optional(string, "not provided")
    session_duration_in_hours = optional(number, 4)
    relay_state               = optional(string, null)
    managed_policies = optional(list(object({
      managed_by  = string
      policy_name = string
      policy_path = optional(string, "/")
    })), [])
    inline_policy_json = optional(string, "")
    # AWS allows at most one permissions boundary per permission set.
    boundary_policy = optional(object({
      managed_by  = string
      policy_name = string
      policy_path = optional(string, "/")
    }), null)
  }))
  default = []

  validation {
    condition     = length(var.permission_sets) == length(distinct([for p in var.permission_sets : p.name]))
    error_message = "\"name\" must be unique in list of \"permission_sets\"."
  }

  validation {
    condition     = alltrue([for ps in var.permission_sets : alltrue([for mp in ps.managed_policies : length(mp.policy_name) > 0])])
    error_message = "Each managed policy must have a non-empty policy_name.\n"
  }

  validation {
    condition     = alltrue([for ps in var.permission_sets : ps.relay_state == null ? true : length(ps.relay_state) > 0])
    error_message = "If provided, each permission set's relay_state must not be empty.\n"
  }

  validation {
    condition     = alltrue([for ps in var.permission_sets : ps.session_duration_in_hours > 0 && ps.session_duration_in_hours <= 12])
    error_message = "If provided, the session_duration_in_hours must be between 1 and 12.\n"
  }

  validation {
    condition     = alltrue([for ps in var.permission_sets : alltrue([for mp in ps.managed_policies : (substr(mp.managed_by, 0, 3) == "aws" || substr(mp.managed_by, 0, 8) == "customer")])])
    error_message = "Each managed policy's managed_by field must start with 'aws' or 'customer'.\n"
  }

  validation {
    condition     = alltrue([for ps in var.permission_sets : alltrue([for mp in ps.managed_policies : can(regex("^\\/(.*\\/)?$", mp.policy_path))])])
    error_message = "Each managed policy's policy_path must start and end with '/'.\n"
  }

  validation {
    condition     = alltrue([for ps in var.permission_sets : ps.inline_policy_json == "" ? true : jsondecode(ps.inline_policy_json) != null])
    error_message = "Each permission set's inline_policy_json must be valid JSON if provided.\n"
  }

  validation {
    condition     = alltrue([for ps in var.permission_sets : ps.boundary_policy == null ? true : (substr(ps.boundary_policy.managed_by, 0, 3) == "aws" || substr(ps.boundary_policy.managed_by, 0, 8) == "customer")])
    error_message = "Each boundary policy's managed_by field must start with 'aws' or 'customer'.\n"
  }

  validation {
    condition     = alltrue([for ps in var.permission_sets : ps.boundary_policy == null ? true : length(ps.boundary_policy.policy_name) > 0])
    error_message = "Each boundary policy must have a non-empty policy_name.\n"
  }

  validation {
    condition     = alltrue([for ps in var.permission_sets : ps.boundary_policy == null ? true : can(regex("^\\/(.*\\/)?$", ps.boundary_policy.policy_path))])
    error_message = "Each boundary policy's policy_path must start and end with '/'.\n"
  }
}


variable "account_assignments" {
  description = "A list of account assignments."
  type = list(object({
    account_id = string,
    permissions = list(object({
      permission_set_name = string
      users               = optional(list(string), [])
      groups              = optional(list(string), [])
    }))
  }))
  default = []

  validation {
    condition     = length(var.account_assignments) == length(distinct([for a in var.account_assignments : a.account_id]))
    error_message = "\"account_id\" must be unique in list of \"account_assignments\"."
  }

  validation {
    condition = alltrue([
      for assignment in var.account_assignments :
      length(assignment.permissions) == length(distinct([for permission in assignment.permissions : permission.permission_set_name]))
    ])
    error_message = "Each \"permission_set_name\" must be unique within each \"account_id\" in the list of \"account_assignments\".\n"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ COMMON
# ---------------------------------------------------------------------------------------------------------------------
variable "resource_tags" {
  description = "A map of tags to assign to the resources in this module."
  type        = map(string)
  default     = {}
}
