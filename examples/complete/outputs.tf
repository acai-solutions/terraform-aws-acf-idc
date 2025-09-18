# ACAI Cloud Foundation (ACF)
# Copyright (C) 2025 ACAI GmbH
# Licensed under AGPL v3
#
# This file is part of ACAI ACF.
# Visit https://www.acai.gmbh or https://docs.acai.gmbh for more information.
# 
# For full license text, see LICENSE file in repository root.
# For commercial licensing, contact: contact@acai.gmbh


output "account_id" {
  description = "AWS Account ID number of the account that owns or contains the calling entity."
  value       = data.aws_caller_identity.current.account_id
}

output "aws_identity_center" {
  value = module.aws_identity_center
}


output "test_success_1" {
  value = module.aws_identity_center.permission_sets.Platform_ViewOnly.arn == module.aws_identity_center.user_assignments["590183833356"][0].permission_set_arn
}

output "test_success_2" {
  value = module.aws_identity_center.permission_sets.Platform_AdminAccess.arn == module.aws_identity_center.user_assignments["992382728088"][0].permission_set_arn
}

output "idc_report" {
  value = jsondecode(aws_lambda_invocation.idc_report.result)
}
