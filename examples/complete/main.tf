# ACAI Cloud Foundation (ACF)
# Copyright (C) 2025 ACAI GmbH
# Licensed under AGPL v3
#
# This file is part of ACAI ACF.
# Visit https://www.acai.gmbh or https://docs.acai.gmbh for more information.
# 
# For full license text, see LICENSE file in repository root.
# For commercial licensing, contact: contact@acai.gmbh


# ---------------------------------------------------------------------------------------------------------------------
# ¦ REQUIREMENTS
# ---------------------------------------------------------------------------------------------------------------------
terraform {
  required_version = ">= 1.3.10"

  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = ">= 4.47"
      configuration_aliases = []
    }
  }
}


# ---------------------------------------------------------------------------------------------------------------------
# ¦ DATA
# ---------------------------------------------------------------------------------------------------------------------
data "aws_region" "current" { provider = aws.org_mgmt }
data "aws_caller_identity" "current" { provider = aws.org_mgmt }

# ---------------------------------------------------------------------------------------------------------------------
# ¦ LOCALS
# ---------------------------------------------------------------------------------------------------------------------
locals {
  permission_sets = [
    {
      "name" : "Platform_AdminAccess"
      "session_duration_in_hours" : 4
      "description" : "Used by Platform Admins"
      "managed_policies" : [
        {
          "managed_by" : "aws"
          "policy_name" : "AdministratorAccess"
        },
      ]
    },
    {
      "name" : "Platform_ViewOnly"
      "session_duration_in_hours" : 4
      "description" : "Used by Platform team for view-only access to member accounts"
      "managed_policies" : [
        {
          "managed_by" : "aws"
          "policy_name" : "ViewOnlyAccess"
          "policy_path" : "/job-function/"
        },
        {
          "managed_by" : "aws"
          "policy_name" : "AWSSupportAccess"
        },
      ]
      "inline_policy_json" : jsonencode({
        "Version" : "2012-10-17",
        "Statement" : [
          {
            "Sid" : "OrganizationsDescribe",
            "Effect" : "Allow",
            "Action" : [
              "organizations:Describe*"
            ],
            "Resource" : [
              "*"
            ]
          }
        ]
      })
    }
  ]

  account_assignments = [
    {
      account_id = "992382728088" # ACAI AWS Testbed Core Security Account
      permissions = [
        {
          permission_set_name = "Platform_AdminAccess"
          users               = ["contact@acai.gmbh"]
        }
      ]
    },
    {
      account_id = "590183833356" # ACAI AWS Testbed Core Logging Account
      permissions = [
        {
          permission_set_name = "Platform_ViewOnly"
          users               = ["contact@acai.gmbh"]
        }
      ]
    }
  ]
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ AWS IAM IDENTITY CENTER
# ---------------------------------------------------------------------------------------------------------------------
module "aws_identity_center" {
  source = "../../"

  permission_sets     = local.permission_sets
  account_assignments = local.account_assignments
  providers = {
    aws = aws.org_mgmt
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ AWS IAM IDENTITY CENTER REPORTING
# ---------------------------------------------------------------------------------------------------------------------
module "idc_crawler_role" {
  source = "../../reporting/principal"

  settings = {
    security = {
      reporting = {
        identity_center = {
          crawled_account = {
            iam_role_name     = "reporting-idc-crawler-role"
            iam_role_trustees = ["992382728088"] # Core Security Account ID
          }
        }
      }
    }
  }
  providers = {
    aws = aws.org_mgmt
  }
  depends_on = [
    module.aws_identity_center
  ]
}

module "idc_report" {
  source = "../../reporting/crawler"

  settings = {
    security = {
      reporting = {
        identity_center = {
          crawler = {
            lambda_name = "report--identity-center"
          }
          crawled_account = {
            iam_role_arn = module.idc_crawler_role.idc_crawler_role_arn
          }
        }
      }
    }
  }
  lambda_settings = {
    runtime = "python3.10"
  }
  providers = {
    aws = aws.core_security
  }
}


resource "aws_lambda_invocation" "idc_report" {
  function_name = "report--identity-center"

  input = <<JSON
{
}
JSON
  depends_on = [
    module.idc_report
  ]
  provider = aws.core_security
}

