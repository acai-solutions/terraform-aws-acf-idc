mock_provider "aws" {
  mock_data "aws_ssoadmin_instances" {
    defaults = {
      arns               = ["arn:aws:sso:::instance/ssoins-1234567890abcdef"]
      identity_store_ids = ["d-1234567890"]
    }
  }
}

variables {
  permission_sets = [
    {
      name = "Platform_AdminAccess"
      managed_policies = [
        { managed_by = "aws", policy_name = "AdministratorAccess" }
      ]
    },
    {
      name = "Platform_ViewOnly"
      managed_policies = [
        { managed_by = "aws", policy_name = "ViewOnlyAccess", policy_path = "/job-function/" }
      ]
      boundary_policy = {
        managed_by  = "aws"
        policy_name = "ReadOnlyAccess"
      }
    },
    {
      name = "Platform_Custom"
      boundary_policy = {
        managed_by  = "customer"
        policy_name = "PermissionsBoundary"
        policy_path = "/boundaries/"
      }
    }
  ]
  account_assignments = []
}

run "boundary_wiring" {
  command = plan

  assert {
    condition     = length(aws_ssoadmin_permissions_boundary_attachment.idc_boundary_aws_managed) == 1
    error_message = "expected exactly one aws-managed boundary attachment"
  }

  assert {
    condition     = aws_ssoadmin_permissions_boundary_attachment.idc_boundary_aws_managed["Platform_ViewOnly"].permissions_boundary[0].managed_policy_arn == "arn:aws:iam::aws:policy/ReadOnlyAccess"
    error_message = "aws-managed boundary ARN is wrong"
  }

  assert {
    condition     = length(aws_ssoadmin_permissions_boundary_attachment.idc_boundary_aws_managed["Platform_ViewOnly"].permissions_boundary[0].customer_managed_policy_reference) == 0
    error_message = "aws-managed boundary must not set customer_managed_policy_reference"
  }

  assert {
    condition     = length(aws_ssoadmin_permissions_boundary_attachment.idc_boundary_customer_managed) == 1
    error_message = "expected exactly one customer-managed boundary attachment"
  }

  assert {
    condition     = aws_ssoadmin_permissions_boundary_attachment.idc_boundary_customer_managed["Platform_Custom"].permissions_boundary[0].customer_managed_policy_reference[0].name == "PermissionsBoundary"
    error_message = "customer-managed boundary name is wrong"
  }

  assert {
    condition     = aws_ssoadmin_permissions_boundary_attachment.idc_boundary_customer_managed["Platform_Custom"].permissions_boundary[0].customer_managed_policy_reference[0].path == "/boundaries/"
    error_message = "customer-managed boundary path is wrong"
  }
}
