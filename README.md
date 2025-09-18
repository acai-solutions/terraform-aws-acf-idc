# terraform-aws-acf-idc Terraform module

<!-- LOGO -->
<a href="https://acai.gmbh">    
  <img src="https://github.com/acai-solutions/acai.public/raw/main/logo/logo_github_readme.png" alt="acai logo" title="ACAI" align="right" height="75" />
</a>

<!-- SHIELDS -->
[![Maintained by acai.gmbh][acai-shield]][acai-url]
[![documentation][acai-docs-shield]][acai-docs-url]  
![module-version-shield]
![terraform-version-shield]  
![trivy-shield]
![checkov-shield]

<!-- BEGIN_ACAI_DOCS -->
This [Terraform][terraform-url] automates the deployment of IAM Identity Center resources to enable Single Sign-On on AWS via an external Identity Provider (e.g. Azure Entra ID).

This module is designed to:

- Provision IdC Permission Sets which act as reusable templates for access policies.
- Configure IdC Assignments that link these Permission Sets to AWS Accounts and specific users or groups.
- Facilitate centralized management of identities and permissions, reducing complexity and improving security governance.

![architecture]

<!-- REQUIREMENTS -->
### Requirements

!!! note "Please ensure that the following requirements are met"
- Enable AWS Organizations and add AWS Accounts.
- Enable IAM Identity Center (successor to AWS Single Sign-On).
- Create identities in IAM Identity Center (Users and Groups) or connect to an external identity provider - see [documentation](https://docs.aws.amazon.com/singlesignon/latest/userguide/manage-your-identity-source-idp.html).
- Ensure that Terraform pipeline is using a role with permissions required for IAM Identity Center management.

<!-- USAGE -->
## Usage

The module can be configured by defining the IdC Permission Sets and the corresponding AWS Account Assignments.

Define IdC Permission Sets:

```hcl
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
}
```

Specify IdC Assignments:

```hcl
locals {
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
```

Finally, provide the above specifications to the ACF IDC Module:

```hcl
module "aws_identity_center" {
  source  = "app.terraform.io/acai-solutions/idc/aws"
  version = "~> 1.0"

  permission_sets     = local.permission_sets
  account_assignments = local.account_assignments
}
```
<!-- END_ACAI_DOCS -->


<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.10 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 4.47 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 4.47 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_ssoadmin_account_assignment.idc_groups](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssoadmin_account_assignment) | resource |
| [aws_ssoadmin_account_assignment.idc_users](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssoadmin_account_assignment) | resource |
| [aws_ssoadmin_customer_managed_policy_attachment.idc_ps_customer_managed](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssoadmin_customer_managed_policy_attachment) | resource |
| [aws_ssoadmin_managed_policy_attachment.idc_ps_aws_managed](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssoadmin_managed_policy_attachment) | resource |
| [aws_ssoadmin_permission_set.idc_ps](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssoadmin_permission_set) | resource |
| [aws_ssoadmin_permission_set_inline_policy.idc_inline](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssoadmin_permission_set_inline_policy) | resource |
| [aws_ssoadmin_permissions_boundary_attachment.idc_boundary_aws_managed](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssoadmin_permissions_boundary_attachment) | resource |
| [aws_ssoadmin_permissions_boundary_attachment.idc_boundary_customer_managed](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssoadmin_permissions_boundary_attachment) | resource |
| [aws_identitystore_group.idc_groups](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/identitystore_group) | data source |
| [aws_identitystore_user.idc_users](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/identitystore_user) | data source |
| [aws_ssoadmin_instances.idc_instance](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssoadmin_instances) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_account_assignments"></a> [account\_assignments](#input\_account\_assignments) | A list of account assignments. | <pre>list(object({<br>    account_id = string,<br>    permissions = list(object({<br>      permission_set_name = string<br>      users               = optional(list(string), [])<br>      groups              = optional(list(string), [])<br>    }))<br>  }))</pre> | `[]` | no |
| <a name="input_permission_sets"></a> [permission\_sets](#input\_permission\_sets) | A list of AWS Identity Center Permission Sets. | <pre>list(object({<br>    name                      = string<br>    description               = optional(string, "not provided")<br>    session_duration_in_hours = optional(number, 4)<br>    relay_state               = optional(string, null)<br>    managed_policies = optional(list(object({<br>      managed_by  = string<br>      policy_name = string<br>      policy_path = optional(string, "/")<br>    })), [])<br>    inline_policy_json = optional(string, "")<br>    boundary_policies = optional(list(object({<br>      managed_by  = string<br>      policy_name = string<br>      policy_path = optional(string, "/")<br>    })), [])<br>  }))</pre> | `[]` | no |
| <a name="input_resource_tags"></a> [resource\_tags](#input\_resource\_tags) | A map of tags to assign to the resources in this module. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_group_assignments"></a> [group\_assignments](#output\_group\_assignments) | Map of group assignments with Single Sign-On. |
| <a name="output_identity_store_arn"></a> [identity\_store\_arn](#output\_identity\_store\_arn) | The Amazon Resource Name (ARN) of the SSO Instance. |
| <a name="output_identity_store_id"></a> [identity\_store\_id](#output\_identity\_store\_id) | Identity Store ID associated with the Single Sign-On Instance. |
| <a name="output_permission_sets"></a> [permission\_sets](#output\_permission\_sets) | Map of permission sets configured to be used with Single Sign-On. |
| <a name="output_user_assignments"></a> [user\_assignments](#output\_user\_assignments) | Map of user assignments with Single Sign-On. |
<!-- END_TF_DOCS -->

<!-- AUTHORS -->
## Authors

This module is maintained by [ACAI GmbH][acai-url].

<!-- LICENSE -->
## License

See [LICENSE][license-url] for full details.

<!-- COPYRIGHT -->
<br />
<br />
<p align="center">Copyright &copy; 2024, 2025 ACAI GmbH</p>

<!-- MARKDOWN LINKS & IMAGES -->
[acai-shield]: https://img.shields.io/badge/maintained_by-acai.gmbh-CB224B?style=flat
[acai-docs-shield]: https://img.shields.io/badge/documentation-docs.acai.gmbh-CB224B?style=flat
[acai-url]: https://acai.gmbh
[acai-docs-url]: https://docs.acai.gmbh
[module-version-shield]: https://img.shields.io/badge/module_version-1.2.2-CB224B?style=flat
[module-release-url]: https://github.com/acai-solutions/terraform-aws-acf-idc/releases
[terraform-version-shield]: https://img.shields.io/badge/tf-%3E%3D1.3.10-blue.svg?style=flat&color=blueviolet
[trivy-shield]: https://img.shields.io/badge/trivy-passed-green
[checkov-shield]: https://img.shields.io/badge/checkov-passed-green
[license-url]: https://github.com/acai-solutions/terraform-aws-acf-idc/tree/main/LICENSE.md
[terraform-url]: https://www.terraform.io
[architecture]: ./docs/terraform-aws-acf-idc.png

