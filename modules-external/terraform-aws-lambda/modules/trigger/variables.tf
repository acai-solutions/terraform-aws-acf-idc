# ACAI AWS Lambda Module
# Copyright (C) 2024, 2025 ACAI GmbH
# Licensed under AGPL v3
#
# Visit https://www.acai.gmbh or https://docs.acai.gmbh for more information.
# 
# For full license text, see LICENSE file in repository root.


variable "trigger_settings" {
  type = object({
    trigger_permissions = list(object({
      principal      = string
      source_arn     = string
      source_account = string
    }))
    sqs = optional(object({
      management_permissions  = list(string)
      access_policy_json_list = list(string)
      inbound_sns_topics = optional(list(object(
        {
          sns_arn            = string
          filter_policy_json = optional(string, null)
        }
      )), [])
    }), null)
    schedule_expression = string
    event_rules = list(object({
      name           = string
      description    = string
      event_bus_name = string
      event_pattern  = string
    }))
  })
}

variable "existing_kms_cmk_arn" {
  description = "KMS key ARN to be used to encrypt logs and sqs messages."
  type        = string
  default     = null
}

variable "runtime_configuration" {
  description = "Configuration related to the runtime environment of the Lambda function."
  type = object({
    account_id     = string
    lambda_name    = string
    lambda_arn     = string
    lambda_timeout = number
  })
}

variable "resource_tags" {
  description = "A map of tags to assign to the resources in this module."
  type        = map(string)
  default     = {}
}
