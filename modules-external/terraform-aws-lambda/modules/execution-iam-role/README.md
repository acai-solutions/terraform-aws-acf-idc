<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.10 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.00 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.00 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_iam_role.execution_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.lambda_context](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.new_lambda_permission_policies](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.execution_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_policy_document.execution_role_trust](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.lambda_context](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.new_lambda_permission_policies](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_execution_iam_role_settings"></a> [execution\_iam\_role\_settings](#input\_execution\_iam\_role\_settings) | Configuration of the for Lambda execution IAM role. | <pre>object({<br/>    new_iam_role = optional(object({<br/>      name                        = string<br/>      path                        = string<br/>      permissions_boundary_arn    = string<br/>      permission_policy_arn_list  = list(string)<br/>      permission_policy_json_list = list(string)<br/>    }), null)<br/>    existing_iam_role_arn                = optional(string, null)<br/>    permissions_fully_externally_managed = bool<br/>  })</pre> | n/a | yes |
| <a name="input_runtime_configuration"></a> [runtime\_configuration](#input\_runtime\_configuration) | Configuration related to the runtime environment of the Lambda function. | <pre>object({<br/>    partition_name = string<br/>    region_name    = string<br/>    region_short   = string<br/>    account_id     = string<br/>    lambda_name    = string<br/>    loggroup_name  = string<br/>  })</pre> | n/a | yes |
| <a name="input_dead_letter_target_arn"></a> [dead\_letter\_target\_arn](#input\_dead\_letter\_target\_arn) | ARN to optional Dead Letter Target. | `string` | `null` | no |
| <a name="input_existing_kms_cmk_arn"></a> [existing\_kms\_cmk\_arn](#input\_existing\_kms\_cmk\_arn) | KMS key ARN to be used to encrypt logs and sqs messages. | `string` | `null` | no |
| <a name="input_resource_tags"></a> [resource\_tags](#input\_resource\_tags) | A map of tags to assign to the resources. | `map(string)` | `{}` | no |
| <a name="input_vpc_subnet_ids"></a> [vpc\_subnet\_ids](#input\_vpc\_subnet\_ids) | List of subnet IDs the Lambda is allowed to create network interfaces in | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_arn"></a> [arn](#output\_arn) | The ARN of the Lambda execution IAM role. |
| <a name="output_id"></a> [id](#output\_id) | The ID of the Lambda execution IAM role. |
| <a name="output_name"></a> [name](#output\_name) | The name of the Lambda execution IAM role. |
| <a name="output_unique_id"></a> [unique\_id](#output\_unique\_id) | The unique ID of the Lambda execution IAM role. |
<!-- END_TF_DOCS -->