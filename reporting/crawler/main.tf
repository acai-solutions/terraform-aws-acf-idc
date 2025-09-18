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
  settings = var.settings.security.reporting.identity_center
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ LAMBDA LAYER
# ---------------------------------------------------------------------------------------------------------------------
locals {
  zip_folder = "${path.module}/lambda-layer/20-zipped/"
}
resource "aws_lambda_layer_version" "idc_libraries_layer" {
  layer_name               = "acf_idc_libraries_layer"
  filename                 = "${local.zip_folder}/idc_libraries_layer.zip"
  compatible_runtimes      = [var.lambda_settings.runtime]
  compatible_architectures = [var.lambda_settings.architecture]
  source_code_hash         = filebase64sha256("${local.zip_folder}/idc_libraries_layer.zip")
}


# ---------------------------------------------------------------------------------------------------------------------
# ¦ LAMBDA
# ---------------------------------------------------------------------------------------------------------------------
module "icd_report" {
  #checkov:skip=CKV_TF_1
  source  = "acai-consulting/lambda/aws"
  version = "1.3.7"

  lambda_settings = {
    function_name = local.settings.crawler.lambda_name
    description   = local.settings.crawler.lambda_description
    layer_arn_list = [
      aws_lambda_layer_version.idc_libraries_layer.arn
    ]
    handler      = "main.lambda_handler"
    config       = var.lambda_settings
    tracing_mode = var.lambda_settings.tracing_mode
    environment_variables = {
      LOG_LEVEL          = var.lambda_settings.log_level
      CRAWLER_ARN        = local.settings.crawled_account.iam_role_arn
      REPORT_BUCKET_NAME = var.settings.security.reporting.bucket_name
    }
    package = {
      source_path = "${path.module}/lambda-files"
    }
  }
  execution_iam_role_settings = {
    new_iam_role = {
      name                        = local.settings.crawler.execution_iam_role_name
      path                        = local.settings.crawler.execution_iam_role_path
      permission_policy_json_list = [data.aws_iam_policy_document.lambda_policy.json]
    }
  }
  resource_tags = local.resource_tags
}


# ---------------------------------------------------------------------------------------------------------------------
# ¦ LAMBDA EXECUTION POLICY
# ---------------------------------------------------------------------------------------------------------------------
data "aws_iam_policy_document" "lambda_policy" {
  statement {
    sid    = "AllowAssumeRole"
    effect = "Allow"
    actions = [
      "sts:AssumeRole"
    ]
    resources = [local.settings.crawled_account.iam_role_arn]
  }

  dynamic "statement" {
    for_each = var.settings.security.reporting.bucket_name != "" ? [1] : []

    content {
      sid    = "AllowS3"
      effect = "Allow"
      actions = [
        "s3:PutObject",
      ]
      resources = [
        format("arn:aws:s3:::%s/idc-reports/*", var.settings.security.reporting.bucket_name)
      ]
    }
  }
}
