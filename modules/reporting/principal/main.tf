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
# ¦ LOCALS
# ---------------------------------------------------------------------------------------------------------------------
locals {
  resource_tags = merge(
    {
      "feature" = "AWS Identity Center Reporting Crawler"
    },
    var.resource_tags
  )
  settings = var.settings.security.reporting.identity_center.crawled_account
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ MASTER ISOLATION IAM ROLE
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_role" "idc_crawler_role" {
  name               = local.settings.iam_role_name
  assume_role_policy = data.aws_iam_policy_document.idc_crawler_role_trust.json
  path               = local.settings.iam_role_path
  tags               = local.resource_tags
}

data "aws_iam_policy_document" "idc_crawler_role_trust" {
  statement {
    sid    = "TrustPolicy"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = local.settings.iam_role_trustees
    }
    actions = [
      "sts:AssumeRole"
    ]
  }
}

resource "aws_iam_role_policy" "idc_crawler_role_permissions" {
  name   = replace(aws_iam_role.idc_crawler_role.name, "role", "policy")
  role   = aws_iam_role.idc_crawler_role.name
  policy = data.aws_iam_policy_document.idc_crawler_role_permissions.json
}

#tfsec:ignore:avd-aws-0057
data "aws_iam_policy_document" "idc_crawler_role_permissions" {
  #checkov:skip=CKV_AWS_356 : readonly permissions
  statement {
    sid    = "AllowOrgMgmt"
    effect = "Allow"
    actions = [
      "sso:Describe*",
      "sso:List*",
      "identitystore:Describe*",
      "identitystore:List*",
      "organizations:ListAccounts"
    ]
    resources = ["*"]
  }
}
