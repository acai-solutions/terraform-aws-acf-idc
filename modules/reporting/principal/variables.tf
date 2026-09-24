# ACAI Cloud Foundation (ACF)
# Copyright (C) 2025 ACAI GmbH
# Licensed under AGPL v3
#
# This file is part of ACAI ACF.
# Visit https://www.acai.gmbh or https://docs.acai.gmbh for more information.
# 
# For full license text, see LICENSE file in repository root.
# For commercial licensing, contact: contact@acai.gmbh


variable "settings" {
  description = "Settings for the IdC Crawler Principal"

  type = object({
    security = object({
      reporting = object({
        identity_center = optional(object({
          crawled_account = object({
            iam_role_name     = string
            iam_role_path     = optional(string, null)
            iam_role_trustees = list(string)
          })
        }), null)
      })
    })
  })
}

variable "resource_tags" {
  description = "A map of tags to assign to the resources in this module."
  type        = map(string)
  default     = {}
}
