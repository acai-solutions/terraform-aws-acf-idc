# ACAI Cloud Foundation (ACF)
# Copyright (C) 2025 ACAI GmbH
# Licensed under AGPL v3
#
# This file is part of ACAI ACF.
# Visit https://www.acai.gmbh or https://docs.acai.gmbh for more information.
# 
# For full license text, see LICENSE file in repository root.
# For commercial licensing, contact: contact@acai.gmbh


output "identity_store_id" {
  description = "Identity Store ID associated with the Single Sign-On Instance."
  value       = local.identity_store_id
}

output "identity_store_arn" {
  description = "The Amazon Resource Name (ARN) of the SSO Instance."
  value       = local.identity_store_arn
}

output "permission_sets" {
  description = "Map of permission sets configured to be used with Single Sign-On."
  value = {
    for set in aws_ssoadmin_permission_set.idc_ps : set.name => set
  }
}

output "user_assignments" {
  description = "Map of user assignments with Single Sign-On."
  value = {
    for assignment in aws_ssoadmin_account_assignment.idc_users : assignment.target_id => assignment...
  }
}

output "group_assignments" {
  description = "Map of group assignments with Single Sign-On."
  value = {
    for assignment in aws_ssoadmin_account_assignment.idc_groups : assignment.target_id => assignment...
  }
}