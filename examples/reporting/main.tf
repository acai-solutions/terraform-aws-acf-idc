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
}

module "idc_report" {
  source = "../../reporting/crawler"

  settings = {
    security = {
      reporting = {
        identity_center = {
          crawler = {
            lambda_name             = "report--identity-center"
            lambda_description      = "report--identity-center"
            execution_iam_role_name = "report--identity-center--execution-role"
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
