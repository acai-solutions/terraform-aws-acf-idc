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
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.0.0"
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ DATA
# ---------------------------------------------------------------------------------------------------------------------
data "aws_partition" "current" {}
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ LOCALS
# ---------------------------------------------------------------------------------------------------------------------
locals {
  resource_tags = merge(
    var.resource_tags,
    {
      "module_lambda_provider" = "ACAI GmbH",
      "module_lambda_origin"   = "terraform registry",
      "module_lambda_source"   = "acai-solutions/lambda/aws",
    },
    can(var.resource_tags["module_stack"]) ? {
      "module_stack" = "${var.resource_tags["module_stack"]}/lambda"
      } : {
      "module_stack" = "lambda"
    }
  )
  region_name_length = length(data.aws_region.current.id)
  region_name_short = format("%s%s%s",
    substr(data.aws_region.current.id, 0, 2),
    substr(data.aws_region.current.id, 3, 1),
    substr(data.aws_region.current.id, local.region_name_length - 1, 1)
  )
  loggroup_name = "/aws/lambda/${var.lambda_settings.function_name}"
  runtime_configuration = {
    partition_name = data.aws_partition.current.partition
    region_name    = data.aws_region.current.id
    region_short   = local.region_name_short
    account_id     = data.aws_caller_identity.current.account_id
    lambda_name    = var.lambda_settings.function_name
    lambda_arn     = "arn:${data.aws_partition.current.partition}:lambda:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:function:${var.lambda_settings.function_name}"
    lambda_timeout = var.lambda_settings.config.timeout
    loggroup_name  = local.loggroup_name
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ MODULE VERSION AS PARAMETER STORE ENTRY
# ---------------------------------------------------------------------------------------------------------------------
locals {
  module_version = "1.6.1"
}
resource "aws_ssm_parameter" "module_version" {
  #checkov:skip=CKV2_AWS_34: AWS SSM Parameter should be Encrypted not required for module version
  name           = lower("/acai/${var.module_context}lambda/${var.lambda_settings.function_name}/moduleversion")
  type           = "String"
  insecure_value = local.module_version
  overwrite      = true
  tags           = local.resource_tags
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ LAMBDA
# ---------------------------------------------------------------------------------------------------------------------
locals {
  package_source_path = var.lambda_settings.package.source_path
  lambda_file_paths   = tolist(fileset(local.package_source_path, "**/*"))

  lambda_package_map = merge(
    { for file in local.lambda_file_paths : file => file("${local.package_source_path}/${file}") },
    coalesce(var.lambda_settings.package.files_to_inject, {})
  )
}

data "archive_file" "lambda_package" {
  count = local.package_source_path != null ? 1 : 0

  type = "zip"
  dynamic "source" {
    for_each = local.lambda_package_map
    content {
      filename = source.key
      content  = source.value
    }
  }
  source {
    filename = "README.md"
    content  = "Add your readme here."
  }
  output_path = "${path.module}/${var.lambda_settings.function_name}_${local.region_name_short}_zipped_package.zip"
}

resource "aws_lambda_function" "this" {
  #checkov:skip=CKV_AWS_272 : #TODO Code Signing will be added in a later release
  #checkov:skip=CKV_AWS_50
  function_name = var.lambda_settings.function_name
  description   = var.lambda_settings.description
  layers        = var.lambda_settings.layer_names == null ? var.lambda_settings.layer_arn_list : var.lambda_settings.layer_names
  role          = module.lambda_execution_iam_role.arn
  handler       = var.lambda_settings.handler

  runtime       = var.lambda_settings.config.runtime
  architectures = [var.lambda_settings.config.architecture]
  timeout       = var.lambda_settings.config.timeout
  memory_size   = var.lambda_settings.config.memory_size

  ephemeral_storage {
    size = var.lambda_settings.config.ephemeral_storage_size
  }

  package_type     = var.lambda_settings.package.type
  image_uri        = try(var.lambda_settings.image_config.image_uri, null)
  filename         = var.lambda_settings.package.source_path == null ? var.lambda_settings.package.local_path : data.archive_file.lambda_package[0].output_path
  source_code_hash = var.lambda_settings.package.source_path == null ? filebase64sha256(var.lambda_settings.package.local_path) : data.archive_file.lambda_package[0].output_base64sha256

  environment {
    variables = var.lambda_settings.environment_variables
  }

  reserved_concurrent_executions = var.lambda_settings.reserved_concurrent_executions
  publish                        = var.lambda_settings.publish
  kms_key_arn                    = var.existing_kms_cmk_arn

  dynamic "tracing_config" {
    for_each = var.lambda_settings.tracing_mode != null ? [1] : []
    content {
      mode = var.lambda_settings.tracing_mode
    }
  }

  dynamic "file_system_config" {
    for_each = var.lambda_settings.file_system_config != null ? [1] : []
    content {
      arn              = var.lambda_settings.file_system_config.arn
      local_mount_path = var.lambda_settings.file_system_config.local_mount_path
    }
  }

  dynamic "dead_letter_config" {
    for_each = var.lambda_settings.error_handling != null ? (var.lambda_settings.error_handling.dead_letter_config != null ? [1] : []) : []
    content {
      target_arn = var.lambda_settings.error_handling.dead_letter_config.target_arn
    }
  }

  dynamic "image_config" {
    for_each = var.lambda_settings.image_config != null ? [1] : []
    content {
      command           = var.lambda_settings.image_config.command
      entry_point       = var.lambda_settings.image_config.entry_point
      working_directory = var.lambda_settings.image_config.working_directory
    }
  }

  dynamic "vpc_config" {
    for_each = var.lambda_settings.vpc_config != null ? [1] : []
    content {
      security_group_ids = var.lambda_settings.vpc_config.security_group_ids
      subnet_ids         = var.lambda_settings.vpc_config.subnet_ids
    }
  }

  tags = local.resource_tags

  depends_on = [
    aws_cloudwatch_log_group.lambda_logs,
    module.lambda_execution_iam_role
  ]
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ CLOUDWATCH LOGS
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "lambda_logs" {
  #checkov:skip=CKV_AWS_338
  name              = local.loggroup_name
  retention_in_days = var.lambda_settings.config.log_retention_in_days
  kms_key_id        = var.existing_kms_cmk_arn
  tags              = local.resource_tags
}

resource "aws_lambda_permission" "allow_lambda_logs" {
  count = var.lambda_settings.error_handling == null ? 0 : (var.lambda_settings.error_handling.central_collector == null ? 0 : 1)

  action         = "lambda:InvokeFunction"
  function_name  = var.lambda_settings.error_handling.central_collector.target_name
  principal      = "logs.${data.aws_region.current.id}.amazonaws.com"
  source_arn     = "arn:${data.aws_partition.current.id}:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:log-group:${local.loggroup_name}:*"
  source_account = data.aws_caller_identity.current.account_id
  depends_on     = [aws_cloudwatch_log_group.lambda_logs]
}

resource "aws_cloudwatch_log_subscription_filter" "lambda_logs_forwarding" {
  count      = var.lambda_settings.error_handling == null ? 0 : (var.lambda_settings.error_handling.central_collector == null ? 0 : 1)
  depends_on = [aws_lambda_permission.allow_lambda_logs[0]]

  name            = "forwarding_${var.lambda_settings.function_name}"
  log_group_name  = aws_cloudwatch_log_group.lambda_logs.name
  destination_arn = var.lambda_settings.error_handling.central_collector.target_arn
  filter_pattern  = var.lambda_settings.error_handling.central_collector.filter
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ TRIGGER
# ---------------------------------------------------------------------------------------------------------------------
module "lambda_trigger" {
  source = "./modules/trigger"
  count  = var.trigger_settings != {} ? 1 : 0

  trigger_settings      = var.trigger_settings
  existing_kms_cmk_arn  = var.existing_kms_cmk_arn
  runtime_configuration = local.runtime_configuration
  resource_tags         = local.resource_tags
  depends_on            = [aws_lambda_function.this]
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ IAM EXECUTION ROLE
# ---------------------------------------------------------------------------------------------------------------------
module "lambda_execution_iam_role" {
  source = "./modules/execution-iam-role"

  execution_iam_role_settings = var.execution_iam_role_settings
  existing_kms_cmk_arn        = var.existing_kms_cmk_arn
  dead_letter_target_arn      = var.lambda_settings.error_handling != null ? (var.lambda_settings.error_handling.dead_letter_config != null ? var.lambda_settings.dead_letter_config.target_arn : null) : null
  runtime_configuration       = local.runtime_configuration
  vpc_subnet_ids              = var.lambda_settings.vpc_config != null ? var.lambda_settings.vpc_config.subnet_ids : []
  resource_tags               = local.resource_tags
}

resource "aws_iam_role_policy_attachment" "aws_xray_write_only_access" {
  count      = var.lambda_settings.tracing_mode == null || var.execution_iam_role_settings.permissions_fully_externally_managed ? 0 : 1
  role       = module.lambda_execution_iam_role.name
  policy_arn = "arn:${local.runtime_configuration.partition_name}:iam::aws:policy/AWSXrayWriteOnlyAccess"
}

resource "aws_iam_role_policy" "triggering_sqs_permissions" {
  count  = var.trigger_settings.sqs != null && !var.execution_iam_role_settings.permissions_fully_externally_managed ? 1 : 0
  name   = "TriggeringSqsPermissions"
  role   = module.lambda_execution_iam_role.name
  policy = data.aws_iam_policy_document.triggering_sqs_permissions.json
}

data "aws_iam_policy_document" "triggering_sqs_permissions" {
  dynamic "statement" {
    for_each = var.trigger_settings.sqs != null ? [1] : []
    content {
      sid       = "AllowTriggerSqs"
      effect    = "Allow"
      actions   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
      resources = [module.lambda_trigger[0].trigger_sqs_arn]
    }
  }
}
