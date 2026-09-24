# ACAI AWS Lambda Module
# Copyright (C) 2024, 2025 ACAI GmbH
# Licensed under AGPL v3
#
# Visit https://www.acai.gmbh or https://docs.acai.gmbh for more information.
# 
# For full license text, see LICENSE file in repository root.


# ---------------------------------------------------------------------------------------------------------------------
# ¦ REQUIREMENTS
# ---------------------------------------------------------------------------------------------------------------------
terraform {
  required_version = ">= 1.3.10"

  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = ">= 5.00"
      configuration_aliases = []
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ DATA
# ---------------------------------------------------------------------------------------------------------------------
data "aws_partition" "current" {}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ LOCALS
# ---------------------------------------------------------------------------------------------------------------------
locals {
  create_new_execution_iam_role = var.execution_iam_role_settings.new_iam_role != null

  new_execution_iam_role_name = local.create_new_execution_iam_role ? coalesce(
    var.execution_iam_role_settings.new_iam_role.name,
    "${var.runtime_configuration.lambda_name}_execution_role"
  ) : ""

  new_execution_iam_role = var.execution_iam_role_settings.new_iam_role
  policy_name_suffix     = format("For%s-%s", replace(title(replace(replace(var.runtime_configuration.lambda_name, "-", " "), "_", " ")), " ", ""), var.runtime_configuration.region_short)

  execution_iam_role_name = local.create_new_execution_iam_role ? (
    aws_iam_role.execution_role[0].name
    ) : (
    element(reverse(split("/", var.execution_iam_role_settings.existing_iam_role_arn)), 0)
  )

  execution_iam_role_arn = local.create_new_execution_iam_role ? (
    replace("arn:${var.runtime_configuration.partition_name}:iam::${var.runtime_configuration.account_id}:role/${trim(local.new_execution_iam_role.path, "/")}/${local.new_execution_iam_role_name}", "////", "/")
    ) : (
    var.execution_iam_role_settings.existing_iam_role_arn
  )
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ LAMBDA EXECUTION IAM ROLE
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_role" "execution_role" {
  count = local.create_new_execution_iam_role ? 1 : 0

  name                 = local.new_execution_iam_role_name
  path                 = local.new_execution_iam_role.path
  assume_role_policy   = data.aws_iam_policy_document.execution_role_trust.json
  permissions_boundary = local.new_execution_iam_role.permissions_boundary_arn
  tags                 = var.resource_tags
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ LAMBDA EXECUTION IAM POLICY
# ---------------------------------------------------------------------------------------------------------------------
data "aws_iam_policy_document" "execution_role_trust" {
  statement {
    sid     = "TrustPolicy"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ ATTACH IAM POLICIES
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_role_policy" "lambda_context" {
  count = var.execution_iam_role_settings.permissions_fully_externally_managed ? 0 : 1

  name   = "AllowLambdaContext${local.policy_name_suffix}"
  role   = local.execution_iam_role_name
  policy = data.aws_iam_policy_document.lambda_context.json
}

data "aws_iam_policy_document" "lambda_context" {
  statement {
    sid       = "LogToCloudWatch"
    effect    = "Allow"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["arn:${data.aws_partition.current.partition}:logs:${var.runtime_configuration.region_name}:${var.runtime_configuration.account_id}:log-group:${var.runtime_configuration.loggroup_name}:*"]
  }

  dynamic "statement" {
    for_each = var.existing_kms_cmk_arn != null ? [1] : []
    content {
      sid       = "AllowKmsCmkAccess"
      effect    = "Allow"
      actions   = ["kms:GenerateDataKey", "kms:Decrypt"]
      resources = [var.existing_kms_cmk_arn]
    }
  }
  dynamic "statement" {
    for_each = var.dead_letter_target_arn != null ? [1] : []
    content {
      sid       = "AllowDeadLetterQueueAccess"
      effect    = "Allow"
      actions   = ["sns:Publish", "sqs:SendMessage"]
      resources = [var.dead_letter_target_arn]
    }
  }
  dynamic "statement" {
    for_each = length(var.vpc_subnet_ids) > 0 ? [1] : []
    content {
      sid    = "AllowVpcActions"
      effect = "Allow"
      actions = [
        "ec2:CreateNetworkInterface",
        "ec2:DescribeNetworkInterfaces",
        "ec2:DescribeSubnets",
        "ec2:DeleteNetworkInterface",
        "ec2:AssignPrivateIpAddresses",
        "ec2:UnassignPrivateIpAddresses"
      ]
      resources = ["*"]
      condition {
        test     = "StringEquals"
        variable = "ec2:Subnet"
        values   = var.vpc_subnet_ids
      }
    }
  }
}

resource "aws_iam_role_policy_attachment" "execution_role" {
  count      = local.create_new_execution_iam_role && !var.execution_iam_role_settings.permissions_fully_externally_managed ? length(var.execution_iam_role_settings.new_iam_role.permission_policy_arn_list) : 0
  role       = aws_iam_role.execution_role[0].name
  policy_arn = local.new_execution_iam_role.permission_policy_arn_list[count.index]
}

resource "aws_iam_role_policy" "new_lambda_permission_policies" {
  count = local.create_new_execution_iam_role && !var.execution_iam_role_settings.permissions_fully_externally_managed ? (
    length(local.new_execution_iam_role.permission_policy_json_list) > 0 ? 1 : 0
  ) : 0

  name   = "AllowCustomPermissions${local.policy_name_suffix}"
  role   = aws_iam_role.execution_role[0].name
  policy = data.aws_iam_policy_document.new_lambda_permission_policies[0].json
}

data "aws_iam_policy_document" "new_lambda_permission_policies" {
  count = local.create_new_execution_iam_role ? (
    length(local.new_execution_iam_role.permission_policy_json_list) > 0 ? 1 : 0
  ) : 0

  source_policy_documents = local.new_execution_iam_role.permission_policy_json_list
}
