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
  account_arn             = format("arn:${data.aws_partition.current.partition}:iam::%s:root", var.runtime_configuration.account_id)
  trigger_sqs_name        = "${var.runtime_configuration.lambda_name}-trigger"
  schedule_eventrule_name = "${var.runtime_configuration.lambda_name}-schedule"

  # Überarbeitete Definition mit ternärem Operator
  trigger_sqs_iam_policy_document = var.trigger_settings.sqs != null ? (
    length(lookup(var.trigger_settings.sqs, "access_policy_json_list", [])) > 0 ||
    length(lookup(var.trigger_settings.sqs, "management_permissions", [])) > 0
  ) : false
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ LAMBDA TRIGGERS
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_lambda_permission" "allowed_triggers" {
  for_each = var.trigger_settings.trigger_permissions != null ? { for idx, perm in var.trigger_settings.trigger_permissions : idx => perm } : {}

  statement_id   = format("AllowExecution%02d", each.key + 1)
  action         = "lambda:InvokeFunction"
  function_name  = var.runtime_configuration.lambda_arn
  principal      = each.value.principal
  source_arn     = each.value.source_arn != "any" ? each.value.source_arn : null
  source_account = each.value.source_account
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ SQS TRIGGER (OPTIONAL)
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_sqs_queue" "lambda_trigger" {
  count = var.trigger_settings.sqs != null ? 1 : 0

  name                       = local.trigger_sqs_name
  kms_master_key_id          = var.existing_kms_cmk_arn
  visibility_timeout_seconds = var.runtime_configuration.lambda_timeout + 100 # at least the max Lambda execution time plus some buffer
  tags                       = var.resource_tags
}

resource "aws_sqs_queue_policy" "lambda_trigger" {
  count = var.trigger_settings.sqs != null ? 1 : 0

  queue_url = aws_sqs_queue.lambda_trigger[0].id
  policy = length(var.trigger_settings.sqs.access_policy_json_list) > 0 || length(var.trigger_settings.sqs.management_permissions) > 0 ? data.aws_iam_policy_document.lambda_trigger_policy[0].json : jsonencode({
    "Version" : "2012-10-17",
    "Statement" : flatten([
      {
        "Sid" : "ManagementPermissions",
        "Effect" : "Allow",
        "Action" : "sqs:*",
        "Resource" : "*",
        "Principal" : {
          "AWS" : local.account_arn
        }
      },
      length(var.trigger_settings.sqs.inbound_sns_topics) != 0 ? [{
        "Sid" : "AllowInboundSns",
        "Effect" : "Allow",
        "Action" : "sqs:SendMessage",
        "Principal" : {
          "Service" : "sns.amazonaws.com"
        },
        "Resource" : "*",
        "Condition" : {
          "ArnLike" : {
            "aws:SourceArn" : [
              for item in var.trigger_settings.sqs.inbound_sns_topics : item.sns_arn
            ]
          }
        }
      }] : []
    ])
  })
}


#tfsec:ignore:AVD-AWS-0097
data "aws_iam_policy_document" "lambda_trigger_policy" {
  #checkov:skip=CKV_AWS_109 : Resource base policy
  #checkov:skip=CKV_AWS_111 : Resource base policy
  #checkov:skip=CKV_AWS_356 : Allow "sqs:*" for account principals
  count = local.trigger_sqs_iam_policy_document ? 1 : 0

  source_policy_documents   = var.trigger_settings.sqs.access_policy_json_list
  override_policy_documents = var.trigger_settings.sqs.management_permissions
  statement {
    sid     = "ManagementPermissions"
    actions = ["sqs:*"]
    effect  = "Allow"
    principals {
      type        = "AWS"
      identifiers = [local.account_arn]
    }
    resources = ["*"]
  }

  dynamic "statement" {
    for_each = length(var.trigger_settings.sqs.inbound_sns_topics) != 0 ? [1] : []
    content {
      sid     = "AllowInboundSns"
      actions = ["sqs:SendMessage"]
      principals {
        type        = "Service"
        identifiers = ["sns.amazonaws.com"]
      }
      resources = ["*"]
      condition {
        test     = "ArnLike"
        variable = "aws:SourceArn"
        values = [
          for item in var.trigger_settings.sqs.inbound_sns_topics : item.sns_arn
        ]
      }
    }
  }
}

resource "aws_sns_topic_subscription" "lambda_trigger" {
  count = var.trigger_settings.sqs != null ? length(var.trigger_settings.sqs.inbound_sns_topics) : 0

  topic_arn     = element(var.trigger_settings.sqs.inbound_sns_topics, count.index).sns_arn
  protocol      = "sqs"
  filter_policy = element(var.trigger_settings.sqs.inbound_sns_topics, count.index).filter_policy_json
  endpoint      = aws_sqs_queue.lambda_trigger[0].arn
}

resource "aws_lambda_event_source_mapping" "lambda_trigger" {
  count = var.trigger_settings.sqs != null ? 1 : 0

  event_source_arn = aws_sqs_queue.lambda_trigger[0].arn
  function_name    = var.runtime_configuration.lambda_name
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ CLOUDWATCH SCHEDULE RULE
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_lambda_permission" "schedule" {
  count = var.trigger_settings.schedule_expression != null ? 1 : 0

  action        = "lambda:InvokeFunction"
  function_name = var.runtime_configuration.lambda_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.schedule[0].arn
}

resource "aws_cloudwatch_event_rule" "schedule" {
  count = var.trigger_settings.schedule_expression != null ? 1 : 0

  name                = local.schedule_eventrule_name
  description         = "Schedule event rule for lambda ${var.runtime_configuration.lambda_name}"
  schedule_expression = var.trigger_settings.schedule_expression
  tags                = var.resource_tags
}

resource "aws_cloudwatch_event_target" "schedule" {
  count = var.trigger_settings.schedule_expression != null ? 1 : 0

  target_id = "attach_schedule_to_lambda"
  rule      = aws_cloudwatch_event_rule.schedule[0].name
  arn       = var.runtime_configuration.lambda_arn
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ CLOUDWATCH PATTERN RULES
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_lambda_permission" "pattern" {
  # Convert the list of objects into a map with unique keys, assuming 'name' is unique
  for_each = { for rule in try(var.trigger_settings.event_rules, []) : rule.name => rule }

  action        = "lambda:InvokeFunction"
  function_name = var.runtime_configuration.lambda_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.pattern[each.key].arn
}

resource "aws_cloudwatch_event_rule" "pattern" {
  for_each = { for rule in try(var.trigger_settings.event_rules, []) : rule.name => rule }

  name           = each.value.name
  description    = "pattern event rule for lambda ${var.runtime_configuration.lambda_name}"
  event_pattern  = each.value.event_pattern
  event_bus_name = each.value.event_bus_name
  tags           = var.resource_tags
}

resource "aws_cloudwatch_event_target" "pattern" {
  # And applied here as well
  for_each = { for rule in try(var.trigger_settings.event_rules, []) : rule.name => rule }

  target_id = "attach_schedule_to_lambda"
  rule      = aws_cloudwatch_event_rule.pattern[each.key].name
  arn       = var.runtime_configuration.lambda_arn
}
