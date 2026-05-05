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
# ¦ VERSIONS
# ---------------------------------------------------------------------------------------------------------------------
terraform {
  required_version = ">= 1.3.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.30"
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ DATA
# ---------------------------------------------------------------------------------------------------------------------
data "aws_caller_identity" "current" { provider = aws.org_mgmt }

# ---------------------------------------------------------------------------------------------------------------------
# ¦ CREATE PROVISIONERS
# ---------------------------------------------------------------------------------------------------------------------
module "create_provisioner_idc" {
  source = "../../cicd-principals/terraform/idc"

  iam_role_settings = {
    name = "idc_cicd_provisioner"
    aws_trustee_arns = [
      "arn:${var.aws_partition}:iam::${var.account_ids.org_mgmt}:root"
    ]
  }
  providers = {
    aws = aws.org_mgmt
  }
}

module "create_provisioner_reporting" {
  source = "../../cicd-principals/terraform/reporting"

  iam_role_settings = {
    name = "idc_reporting_cicd_provisioner"
    aws_trustee_arns = [
      "arn:${var.aws_partition}:iam::${var.account_ids.org_mgmt}:root"
    ]
  }
  providers = {
    aws = aws.core_security
  }
}

provider "aws" {
  region = var.aws_region
  alias  = "idc"
  assume_role {
    role_arn = module.create_provisioner_idc.iam_role_arn
  }
}

provider "aws" {
  region = var.aws_region
  alias  = "reporting"
  assume_role {
    role_arn = module.create_provisioner_reporting.iam_role_arn
  }
}

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
      account_id = var.account_ids.core_security
      permissions = [
        {
          permission_set_name = "Platform_AdminAccess"
          users               = [var.assignment_user_name]
        }
      ]
    },
    {
      account_id = var.account_ids.core_logging
      permissions = [
        {
          permission_set_name = "Platform_ViewOnly"
          users               = [var.assignment_user_name]
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
    aws = aws.idc
  }
  depends_on = [module.create_provisioner_idc]
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
            iam_role_trustees = [var.account_ids.core_security]
          }
        }
      }
    }
  }
  providers = {
    aws = aws.idc
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
    aws = aws.reporting
  }
  depends_on = [module.create_provisioner_reporting]
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
  provider = aws.reporting
}
