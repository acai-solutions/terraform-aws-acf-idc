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
| [aws_cloudwatch_event_rule.pattern](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule) | resource |
| [aws_cloudwatch_event_rule.schedule](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule) | resource |
| [aws_cloudwatch_event_target.pattern](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |
| [aws_cloudwatch_event_target.schedule](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |
| [aws_lambda_event_source_mapping.lambda_trigger](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_event_source_mapping) | resource |
| [aws_lambda_permission.allowed_triggers](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_lambda_permission.pattern](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_lambda_permission.schedule](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_sns_topic_subscription.lambda_trigger](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_subscription) | resource |
| [aws_sqs_queue.lambda_trigger](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue) | resource |
| [aws_sqs_queue_policy.lambda_trigger](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue_policy) | resource |
| [aws_iam_policy_document.lambda_trigger_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_runtime_configuration"></a> [runtime\_configuration](#input\_runtime\_configuration) | Configuration related to the runtime environment of the Lambda function. | <pre>object({<br/>    account_id     = string<br/>    lambda_name    = string<br/>    lambda_arn     = string<br/>    lambda_timeout = number<br/>  })</pre> | n/a | yes |
| <a name="input_trigger_settings"></a> [trigger\_settings](#input\_trigger\_settings) | n/a | <pre>object({<br/>    trigger_permissions = list(object({<br/>      principal      = string<br/>      source_arn     = string<br/>      source_account = string<br/>    }))<br/>    sqs = optional(object({<br/>      management_permissions  = list(string)<br/>      access_policy_json_list = list(string)<br/>      inbound_sns_topics = optional(list(object(<br/>        {<br/>          sns_arn            = string<br/>          filter_policy_json = optional(string, null)<br/>        }<br/>      )), [])<br/>    }), null)<br/>    schedule_expression = string<br/>    event_rules = list(object({<br/>      name           = string<br/>      description    = string<br/>      event_bus_name = string<br/>      event_pattern  = string<br/>    }))<br/>  })</pre> | n/a | yes |
| <a name="input_existing_kms_cmk_arn"></a> [existing\_kms\_cmk\_arn](#input\_existing\_kms\_cmk\_arn) | KMS key ARN to be used to encrypt logs and sqs messages. | `string` | `null` | no |
| <a name="input_resource_tags"></a> [resource\_tags](#input\_resource\_tags) | A map of tags to assign to the resources in this module. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cloudwatch_event_rule_arns"></a> [cloudwatch\_event\_rule\_arns](#output\_cloudwatch\_event\_rule\_arns) | ARNs of the created CloudWatch event rules. |
| <a name="output_scheduler_arn"></a> [scheduler\_arn](#output\_scheduler\_arn) | The ARN of the CloudWatch event rule for schedule. |
| <a name="output_trigger_sqs_arn"></a> [trigger\_sqs\_arn](#output\_trigger\_sqs\_arn) | The ARN of the SQS queue configured as a trigger for the Lambda function. |
| <a name="output_trigger_sqs_url"></a> [trigger\_sqs\_url](#output\_trigger\_sqs\_url) | The URL of the SQS queue configured as a trigger for the Lambda function. |
<!-- END_TF_DOCS -->