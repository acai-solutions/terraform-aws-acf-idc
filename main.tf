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
# ¦ IDC INSTANCE
# ---------------------------------------------------------------------------------------------------------------------
data "aws_ssoadmin_instances" "idc_instance" {}

locals {
  resource_tags = merge(
    var.resource_tags,
    {
      "module_provider" = "ACAI GmbH",
      "module_name"     = "terraform-aws-acf-idc",
      "module_source"   = "github.com/acai-consulting/terraform-aws-acf-idc",
      "module_version"  = /*inject_version_start*/ "1.2.2" /*inject_version_end*/
    }
  )
  identity_store_id  = tolist(data.aws_ssoadmin_instances.idc_instance.identity_store_ids)[0]
  identity_store_arn = tolist(data.aws_ssoadmin_instances.idc_instance.arns)[0]
}


# ---------------------------------------------------------------------------------------------------------------------
# ¦ IDC PERMISSION SETS
# ---------------------------------------------------------------------------------------------------------------------
locals {
  policies_nested = distinct(flatten([
    for set in var.permission_sets : [
      for policy in set.managed_policies : {
        index : "${set.name}/POLICY/${policy.policy_name}"
        permission_set : set.name
        managed_by : policy.managed_by
        policy_name : policy.policy_name
        policy_path : policy.policy_path
      }
    ]
  ]))
}

resource "aws_ssoadmin_permission_set" "idc_ps" {
  for_each = {
    for ps in var.permission_sets : ps.name => ps
  }

  name             = each.value.name
  description      = each.value.description
  instance_arn     = local.identity_store_arn
  session_duration = "PT${each.value.session_duration_in_hours}H"
  relay_state      = each.value.relay_state
  tags             = local.resource_tags
}

resource "aws_ssoadmin_managed_policy_attachment" "idc_ps_aws_managed" {
  for_each = {
    for policy in local.policies_nested : policy.index => policy
    if lower(policy.managed_by) == "aws"
  }

  instance_arn       = local.identity_store_arn
  managed_policy_arn = "arn:aws:iam::aws:policy${each.value.policy_path}${each.value.policy_name}"
  permission_set_arn = aws_ssoadmin_permission_set.idc_ps[each.value.permission_set].arn
}

resource "aws_ssoadmin_customer_managed_policy_attachment" "idc_ps_customer_managed" {
  for_each = {
    for policy in local.policies_nested : policy.index => policy
    if lower(policy.managed_by) == "customer"
  }

  instance_arn       = local.identity_store_arn
  permission_set_arn = aws_ssoadmin_permission_set.idc_ps[each.value.permission_set].arn
  customer_managed_policy_reference {
    name = each.value.policy_name
    path = each.value.policy_path
  }
}

resource "aws_ssoadmin_permission_set_inline_policy" "idc_inline" {
  for_each = {
    for set in var.permission_sets : set.name => set.inline_policy_json
    if length(try(set.inline_policy_json, "")) > 0
  }

  inline_policy      = each.value
  instance_arn       = local.identity_store_arn
  permission_set_arn = aws_ssoadmin_permission_set.idc_ps[each.key].arn
}

resource "aws_ssoadmin_permissions_boundary_attachment" "idc_boundary_aws_managed" {
  for_each = {
    for set in var.permission_sets : set.name => set.boundary_policy
    if lower(try(set.boundary_policy.managed_by, "")) == "aws"
  }

  instance_arn       = local.identity_store_arn
  permission_set_arn = aws_ssoadmin_permission_set.idc_ps[each.key].arn
  permissions_boundary {
    customer_managed_policy_reference {
      name = each.value.policy_name
      path = each.value.policy_path
    }
  }
}

resource "aws_ssoadmin_permissions_boundary_attachment" "idc_boundary_customer_managed" {
  for_each = {
    for set in var.permission_sets : set.name => set.boundary_policy
    if lower(try(set.boundary_policy.managed_by, "")) == "customer"
  }

  instance_arn       = local.identity_store_arn
  permission_set_arn = aws_ssoadmin_permission_set.idc_ps[each.key].arn
  permissions_boundary {
    customer_managed_policy_reference {
      name = each.value.policy_name
      path = each.value.policy_path
    }
  }
}


# ---------------------------------------------------------------------------------------------------------------------
# ¦ IDC ACCOUNT ASSIGNMENTS - USERS
# ---------------------------------------------------------------------------------------------------------------------
locals {
  users_with_assignment = distinct(flatten([
    for assignment in var.account_assignments : [
      for permission in assignment.permissions : [
        for user in permission.users : lower(user)
      ]
    ]
  ]))
}

data "aws_identitystore_user" "idc_users" {
  for_each = toset(local.users_with_assignment)

  identity_store_id = local.identity_store_id

  alternate_identifier {
    unique_attribute {
      attribute_path = "UserName"
      # workaround in case UserName is cut off by scim sync
      attribute_value = substr(each.value, 0, 54)
    }
  }
}

locals {
  identity_store_users = { for user in data.aws_identitystore_user.idc_users : user.user_name => user.user_id }

  user_assignments = distinct(flatten([
    for account in var.account_assignments : [
      for permission in account.permissions : [
        for user in permission.users : {
          index : lower("${account.account_id}/${permission.permission_set_name}/${user}"),
          account_id : account.account_id,
          permission_set : permission.permission_set_name,
          user_name : user
        }
      ]
    ]
  ]))
}

resource "aws_ssoadmin_account_assignment" "idc_users" {
  for_each = {
    for user in local.user_assignments : user.index => user
  }

  instance_arn       = local.identity_store_arn
  permission_set_arn = aws_ssoadmin_permission_set.idc_ps[each.value.permission_set].arn

  principal_id   = try(local.identity_store_users[each.value.user_name], "user_does_not_exist")
  principal_type = "USER"

  target_id   = each.value.account_id
  target_type = "AWS_ACCOUNT"

  lifecycle {
    # Permission_set must exist in var.permission_sets
    precondition {
      condition     = contains([for set in var.permission_sets : set.name], each.value.permission_set)
      error_message = "Permission set \"${each.value.permission_set}\" is missing in \"var.permission_sets\"."
    }

    # User must exist in local.identity_store_users
    precondition {
      condition     = try(local.identity_store_users[each.value.user_name], "user_does_not_exist") != "user_does_not_exist"
      error_message = "User \"${each.value.user_name}\" is missing in identity store."
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ IDC ACCOUNT ASSIGNMENTS - GROUPS
# ---------------------------------------------------------------------------------------------------------------------
locals {
  groups_with_assignment = distinct(flatten([
    for assignment in var.account_assignments : [
      for permission in assignment.permissions : [
        for group in permission.groups : lower(group)
      ]
    ]
  ]))
}

data "aws_identitystore_group" "idc_groups" {
  for_each = toset(local.groups_with_assignment)

  identity_store_id = local.identity_store_id

  alternate_identifier {
    unique_attribute {
      attribute_path  = "DisplayName"
      attribute_value = each.value
    }
  }
}

locals {
  identity_store_groups = { for group in data.aws_identitystore_group.idc_groups : lower(group.display_name) => group.group_id }

  group_assignments = distinct(flatten([
    for account in var.account_assignments : [
      for permission in account.permissions : [
        for group in permission.groups : {
          index : "${account.account_id}/${permission.permission_set_name}/${group}",
          account_id : account.account_id,
          permission_set : permission.permission_set_name,
          group_name : lower(group)
        }
      ]
    ]
  ]))
}

resource "aws_ssoadmin_account_assignment" "idc_groups" {
  for_each = {
    for group in local.group_assignments : group.index => group
  }

  instance_arn       = local.identity_store_arn
  permission_set_arn = aws_ssoadmin_permission_set.idc_ps[each.value.permission_set].arn

  principal_id   = try(local.identity_store_groups[lower(each.value.group_name)], "group_does_not_exist")
  principal_type = "GROUP"

  target_id   = each.value.account_id
  target_type = "AWS_ACCOUNT"

  lifecycle {
    # Permission_set must exist in var.permission_sets
    precondition {
      condition     = contains([for set in var.permission_sets : set.name], each.value.permission_set)
      error_message = "Permission set \"${each.value.permission_set}\" is missing in \"var.permission_sets\"."
    }

    # Group must exist in local.identity_store_users
    precondition {
      condition     = try(local.identity_store_groups[each.value.group_name], "group_does_not_exist") != "group_does_not_exist"
      error_message = "Group \"${each.value.group_name}\" is missing in identity store."
    }
  }
}
