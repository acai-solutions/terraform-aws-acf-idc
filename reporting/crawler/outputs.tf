# ACAI Cloud Foundation (ACF)
# Copyright (C) 2025 ACAI GmbH
# Licensed under AGPL v3
#
# This file is part of ACAI ACF.
# Visit https://www.acai.gmbh or https://docs.acai.gmbh for more information.
# 
# For full license text, see LICENSE file in repository root.
# For commercial licensing, contact: contact@acai.gmbh



output "core_configuration_to_write" {
  description = "This must be in sync with the Account Baselining"
  # https://dev.azure.com/ipmsecurity/AWS-MA-Core-Security/_git/terraform-aws-account-baseline-stacksets?path=/stacksets_security.tf&version=GBmain&_a=contents
  value = {
    security = {
      reporting = {
        identity_center = {
          crawler = {
            iam_role_arn = module.icd_report.execution_iam_role.arn
          }
        }
      }
    }
  }
}
