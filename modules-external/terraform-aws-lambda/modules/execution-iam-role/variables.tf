# ACAI AWS Lambda Module
# Copyright (C) 2024, 2025 ACAI GmbH
# Licensed under AGPL v3
#
# Visit https://www.acai.gmbh or https://docs.acai.gmbh for more information.
# 
# For full license text, see LICENSE file in repository root.


variable "execution_iam_role_settings" {
  description = "Configuration of the for Lambda execution IAM role."
  type = object({
    new_iam_role = optional(object({
      name                        = string
      path                        = string
      permissions_boundary_arn    = string
      permission_policy_arn_list  = list(string)
      permission_policy_json_list = list(string)
    }), null)
    existing_iam_role_arn                = optional(string, null)
    permissions_fully_externally_managed = bool
  })
}

variable "runtime_configuration" {
  description = "Configuration related to the runtime environment of the Lambda function."
  type = object({
    partition_name = string
    region_name    = string
    region_short   = string
    account_id     = string
    lambda_name    = string
    loggroup_name  = string
  })
}

variable "existing_kms_cmk_arn" {
  description = "KMS key ARN to be used to encrypt logs and sqs messages."
  type        = string
  default     = null
}

variable "dead_letter_target_arn" {
  description = "ARN to optional Dead Letter Target."
  type        = string
  default     = null
}

variable "vpc_subnet_ids" {
  description = "List of subnet IDs the Lambda is allowed to create network interfaces in"
  type        = list(string)
  default     = []
}

variable "resource_tags" {
  description = "A map of tags to assign to the resources."
  type        = map(string)
  default     = {}
}
