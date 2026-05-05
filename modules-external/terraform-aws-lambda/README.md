# terraform-aws-lambda

<!-- LOGO -->
<a href="https://acai.gmbh">    
  <img src="https://github.com/acai-solutions/acai.public/raw/main/logo/logo_github_readme.png" alt="acai logo" title="ACAI" align="right" height="75" />
</a>

<!-- SHIELDS -->
[![Maintained by acai.gmbh][acai-shield]][acai-url]
[![documentation][acai-docs-shield]][acai-docs-url]  
![module-version-shield]  
![terraform-tested-shield]
![opentofu-tested-shield]    
![aws-tested-shield]
![aws-esc-tested-shield]  
![trivy-shield]
![checkov-shield]

<!-- DESCRIPTION -->
[Terraform][terraform-url] module to deploy Lambda resources on [AWS][aws-url]

<!-- ARCHITECTURE -->
## Architecture

![architecture][architecture-png]

<!-- FEATURES -->
## Features

* Creates a Lambda Function
* Creates a CloudWatch Log Group for Lambda logs
* Execution IAM Role
  * Option 1: Create a new Lambda Execution IAM Role and attach default and provided policies
  * Option 2: Provide the name of an existing Lambda Execution IAM Role
* Triggers (optional)
  * Create a SQS for triggering the Lambda
  * Create a scheduling Event Rule
  * Create CloudWatch Event Rules

<!-- EXAMPLES -->
## Examples

### Use-Case 1

This Lambda will list all CloudWatch LogGroups and IAM Roles and return them as JSON.
This use-case will create a Lambda, with a new Execution IAM Role and provides a lambda_permission policy-snip to perform the tasks.

Location: [`./examples/use-case-1`](./examples/use-case-1/)

``` hcl
data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "lambda_permission" {
  # enable IAM in logging account
  statement {
    effect = "Allow"
    actions = [
      "logs:DescribeLogGroups",
      "iam:ListRoles"
    ]
    resources = ["*"]
  }
}

module "use_case_1_lambda" {
  source = "../../"

  lambda_settings = {
    function_name = var.function_name
    description   = "This Lambda will list all CloudWatch LogGroups and IAM Roles and return them as JSON"
    handler       = "main.lambda_handler"
    config = {
      runtime     = "python3.10"
      memory_size = 128
      timeout     = 360
    }
    environment_variables = {
      ACCOUNT_ID = data.aws_caller_identity.current.account_id
    }
    package = {
      source_path = "${path.module}/lambda_files"
    }
  }

  execution_iam_role_settings = {
    new_iam_role = {
      permission_policy_json_list = [
        data.aws_iam_policy_document.lambda_permission.json
      ]
    }
  }

  resource_tags = var.resource_tags
}
```

### Use-Case 2

This Lambda will list all Event-Rules and return them as JSON
This use-case will create a Lambda, with a new Execution IAM Role and provides a lambda_permission policy-snip to perform the tasks.
The Lambda will be scheduled and will be triggered by an Event Rule, listening for terminated EC2 instances.

Location: [`./examples/use-case-2`](./examples/use-case-2/)

``` hcl
data "aws_caller_identity" "current" {}

locals {
  triggering_event_rules = [{
    name = "use_case_2_event"
    event_pattern = jsonencode(
      {
        "source" : ["aws.ec2"],
        "detail-type" : ["EC2 Instance State-change Notification"],
        "detail" : {
          "state" : ["terminated"]
        }
      }
    )
  }]
}

data "aws_iam_policy_document" "lambda_permission" {
  statement {
    effect    = "Allow"
    actions   = [
      "events:List*",
      "ec2:DescribeInstances"
    ]
    resources = ["*"]
  }
}

module "test_lambda" {
  source = "../../"

  lambda_settings = {
    function_name = var.function_name
    description   = "This Lambda will list all Event-Rules and and EC2 instances and return them as JSON"
    handler       = "main.lambda_handler"
    config = {
      runtime     = "python3.10"
      memory_size = 128
      timeout     = 360
    }
    environment_variables = {
      ACCOUNT_ID = data.aws_caller_identity.current.account_id
    }
    package = {
      source_path = "${path.module}/lambda_files"
    }
  }

  trigger_settings = {
    schedule_expression = "cron(0 1 * * ? *)"
    event_rules         = local.triggering_event_rules
  }

  execution_iam_role_settings = {
    new_iam_role = {
      permission_policy_json_list = [
        data.aws_iam_policy_document.lambda_permission.json
      ]
    }
  }

  resource_tags = var.resource_tags
}
```

### Use-Case 3

In this use-case two Lambdas will share an IAM Role that is "externally" provided.

Location: [`./examples/use-case-3`](./examples/use-case-3/)

``` hcl
# ---------------------------------------------------------------------------------------------------------------------
# ¦ DATA
# ---------------------------------------------------------------------------------------------------------------------
data "aws_caller_identity" "current" {}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ SHARED IAM ROLE
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_role" "lambda_exec_role" {
  name = "use_case_3_shared_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Effect = "Allow"
        Sid    = ""
      },
    ]
  })

  inline_policy {
    name   = "inline_lambda_execution_policy"
    policy = data.aws_iam_policy_document.lambda_permission.json
  }
}

#tfsec:ignore:avd-aws-0057
data "aws_iam_policy_document" "lambda_permission" {
  statement {
    effect = "Allow"
    actions = [
      "logs:DescribeLogGroups",
      "iam:ListRoles",
      "events:List*",
      "ec2:DescribeInstances"
    ]
    resources = ["*"]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ Lambda 1
# ---------------------------------------------------------------------------------------------------------------------
module "use_case_3_lambda1" {
  source = "../../"

  lambda_settings = {
    function_name = "${var.function_name}-1"
    description   = "This Lambda will list all CloudWatch LogGroups and IAM Roles and return them as JSON"
    handler       = "main.lambda_handler"
    config = {
      runtime = "python3.10"
    }
    environment_variables = {
      ACCOUNT_ID = data.aws_caller_identity.current.account_id
    }
    package = {
      source_path = "${path.module}/lambda1_files"
    }
  }
  execution_iam_role_settings = {
    existing_iam_role_arn = aws_iam_role.lambda_exec_role.arn
  }
  resource_tags = var.resource_tags
  depends_on = [
    aws_iam_role.lambda_exec_role
  ]
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ Lambda 2
# ---------------------------------------------------------------------------------------------------------------------
locals {
  triggering_event_rules = [{
    name = "use_case_3_event"
    event_pattern = jsonencode(
      {
        "source" : ["aws.ec2"],
        "detail-type" : ["EC2 Instance State-change Notification"],
        "detail" : {
          "state" : ["terminated"]
        }
      }
    )
  }]
}

module "use_case_3_lambda2" {
  source = "../../"

  lambda_settings = {
    function_name = "${var.function_name}-2"
    description   = "This Lambda will list all Event-Rules and and EC2 instances and return them as JSON"
    handler       = "main.lambda_handler"
    config = {
      runtime     = "python3.10"
      memory_size = 512
      timeout     = 360
    }
    environment_variables = {
      ACCOUNT_ID = data.aws_caller_identity.current.account_id
    }
    package = {
      source_path = "${path.module}/lambda2_files"
    }
  }
  trigger_settings = {
    schedule_expression = "cron(0 1 * * ? *)"
    event_rules         = local.triggering_event_rules
  }
  execution_iam_role_settings = {
    existing_iam_role_arn = aws_iam_role.lambda_exec_role.arn
  }
  resource_tags = var.resource_tags
  depends_on = [
    aws_iam_role.lambda_exec_role
  ]
}
```

### Use-Case 4

In this use-case an 'existing' KMS CMK will be provided and a SQS will be enabled.
The Lambda module will provision the SQS and wire it up with the Lambda.
The KMS CMK will be used for the SQS queue and the CloudWatch LogGroup.

Location: [`./examples/use-case-4`](./examples/use-case-4/)

``` hcl
# ---------------------------------------------------------------------------------------------------------------------
# ¦ DATA
# ---------------------------------------------------------------------------------------------------------------------
data "aws_caller_identity" "current" {}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ SHARED KMS CMK
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_kms_key" "lambda_cmk" {
  description             = "KMS CMK for Lambda Encryption/Decryption"
  enable_key_rotation     = true
  deletion_window_in_days = 10
  policy                  = data.aws_iam_policy_document.lambda_kms_policy.json
}
resource "aws_kms_alias" "lambda_cmk_alias" {
  name          = "alias/use_case_4_cmk"
  target_key_id = aws_kms_key.lambda_cmk.key_id
}
#tfsec:ignore:avd-aws-0057
data "aws_iam_policy_document" "lambda_kms_policy" {
  statement {
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
  }
  statement {
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type = "Service"
      identifiers = [
        "logs.amazonaws.com",
        "lambda.amazonaws.com",
        "sns.amazonaws.com",
        "sqs.amazonaws.com",
      ]
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ INBOUND SNS
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_sns_topic" "triggering_sns" {
  name              = format("%s-feed", var.function_name)
  kms_master_key_id = aws_kms_key.lambda_cmk.key_id
}

resource "aws_sns_topic_policy" "triggering_sns" {
  arn    = aws_sns_topic.triggering_sns.arn
  policy = data.aws_iam_policy_document.triggering_sns.json
}

data "aws_iam_policy_document" "triggering_sns" {
  statement {
    sid     = "AllowedPublishers"
    actions = ["sns:Publish"]
    effect  = "Allow"
    principals {
      type = "AWS"
      identifiers = [
        format("arn:aws:iam::%s:root", data.aws_caller_identity.current.id)
      ]
    }
    resources = [aws_sns_topic.triggering_sns.arn]
  }
  statement {
    sid     = "AllowedSubscribers"
    actions = ["sns:Subscribe"]
    effect  = "Allow"
    principals {
      type = "AWS"
      identifiers = [
        format("arn:aws:iam::%s:root", data.aws_caller_identity.current.id)
      ]
    }
    resources = [aws_sns_topic.triggering_sns.arn]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ Lambda
# ---------------------------------------------------------------------------------------------------------------------
data "aws_iam_policy_document" "lambda_permission" {
  statement {
    effect = "Allow"
    actions = [
      "logs:DescribeLogGroups",
      "iam:ListRoles"
    ]
    resources = ["*"]
  }
}

module "use_case_4_lambda" {
  source = "../../"

  lambda_settings = {
    function_name = var.function_name
    description   = "This Lambda will list all CloudWatch LogGroups and IAM Roles and return them as JSON"
    handler       = "main.lambda_handler"
    config = {
      runtime = "python3.10"
    }
    environment_variables = {
      ACCOUNT_ID = data.aws_caller_identity.current.account_id
    }
    package = {
      source_path = "${path.module}/lambda_files"
    }
  }
  trigger_settings = {
    sqs = {
      inbound_sns_topics = [{
        sns_arn            = aws_sns_topic.triggering_sns.arn
        filter_policy_json = null
      }]
    }
  }
  execution_iam_role_settings = {
    new_iam_role = {
      permission_policy_json_list = [
        data.aws_iam_policy_document.lambda_permission.json
      ]
    }
  }
  existing_kms_cmk_arn = aws_kms_key.lambda_cmk.arn
  resource_tags        = var.resource_tags
}
```

### Use-Case 5

This Lambda will inject several files with data rendered at runtime into the Lambda Package.

Location: [`./examples/use-case-5`](./examples/use-case-5/)

``` hcl
locals {
  file_paths = fileset("${path.module}/semper-policies/", "**/*.json")
  semper_policies_map = {
    for file in local.file_paths :
    "semper-policies/${file}" => file("${path.module}/semper-policies/${file}")
  }
}

module "use_case_5_lambda" {
  #checkov:skip=CKV_AWS_50
  source = "../../"

  lambda_settings = {
    function_name = "${var.function_name}_5"
    description   = "This sample will inject the content of a 'local' folder into the Lambda package"
    handler       = "main.lambda_handler"
    config = {
      runtime = "python3.12"
    }
    package = {
      source_path = "${path.module}/lambda-files"
      files_to_inject = merge(
        local.semper_policies_map,
        { 
          "README.md" : "Override README.md" 
          "sub-folder/test.json" = <<-EOT
{
    "accountId": "${data.aws_caller_identity.current.account_id}",
    "accountName": "acai_testbed-lab1_wl2",
    "accountStatus": "ACTIVE"
}
EOT
        }
      )
    }
  }
  execution_iam_role_settings = {
    new_iam_role = {}
  }
  #worker_is_windows = true
  resource_tags = var.resource_tags
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.10 |
| <a name="requirement_archive"></a> [archive](#requirement\_archive) | >= 2.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.00 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_archive"></a> [archive](#provider\_archive) | >= 2.0.0 |
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.00 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_lambda_execution_iam_role"></a> [lambda\_execution\_iam\_role](#module\_lambda\_execution\_iam\_role) | ./modules/execution-iam-role | n/a |
| <a name="module_lambda_trigger"></a> [lambda\_trigger](#module\_lambda\_trigger) | ./modules/trigger | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_group.lambda_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_subscription_filter.lambda_logs_forwarding](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_subscription_filter) | resource |
| [aws_iam_role_policy.triggering_sqs_permissions](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.aws_xray_write_only_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_lambda_function.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_permission.allow_lambda_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_ssm_parameter.module_version](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [archive_file.lambda_package](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.triggering_sqs_permissions](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_lambda_settings"></a> [lambda\_settings](#input\_lambda\_settings) | Settings for the Lambda function. | <pre>object({<br/>    function_name  = string<br/>    description    = optional(string, "not provided")<br/>    layer_names    = optional(list(string), null) # will be deprecated<br/>    layer_arn_list = optional(list(string), null)<br/>    handler        = optional(string, "main.lambda_handler")<br/>    config = object({<br/>      runtime                = string<br/>      architecture           = optional(string, "x86_64")<br/>      timeout                = optional(number, 30)<br/>      memory_size            = optional(number, 512)<br/>      ephemeral_storage_size = optional(number, 512)<br/>      log_retention_in_days  = optional(number, 90)<br/>    })<br/>    error_handling = optional(object({<br/>      dead_letter_config = optional(object({<br/>        target_arn = string<br/>      }), null)<br/>      central_collector = optional(object({<br/>        target_name = string<br/>        target_arn  = string<br/>        filter      = optional(string, "ERROR")<br/>      }), null)<br/>    }), null)<br/>    package = object({<br/>      type            = optional(string, "Zip")<br/>      local_path      = optional(string, null)<br/>      source_path     = optional(string, null)<br/>      files_to_inject = optional(map(string), null) # map with path/filename as key and file-content as value<br/>    })<br/>    environment_variables          = optional(map(string), {})<br/>    reserved_concurrent_executions = optional(number, -1)<br/>    publish                        = optional(bool, false)<br/>    tracing_mode                   = optional(string, "Active")<br/>    file_system_config = optional(object({<br/>      arn              = string<br/>      local_mount_path = string<br/>    }), null)<br/>    image_config = optional(object({<br/>      image_uri         = optional(string)<br/>      command           = optional(list(string), null)<br/>      entry_point       = optional(list(string), null)<br/>      working_directory = optional(string, null)<br/>    }), null)<br/>    vpc_config = optional(object({<br/>      security_group_ids = list(string)<br/>      subnet_ids         = list(string)<br/>    }), null)<br/>  })</pre> | n/a | yes |
| <a name="input_execution_iam_role_settings"></a> [execution\_iam\_role\_settings](#input\_execution\_iam\_role\_settings) | Settings of the for Lambda execution IAM role. | <pre>object({<br/>    new_iam_role = optional(object({<br/>      name                        = optional(string)<br/>      path                        = optional(string, "/")<br/>      permissions_boundary_arn    = optional(string)<br/>      permission_policy_arn_list  = optional(list(string), [])<br/>      permission_policy_json_list = optional(list(string), [])<br/>    }), null)<br/>    existing_iam_role_arn                = optional(string, null)<br/>    permissions_fully_externally_managed = optional(bool, false)<br/>  })</pre> | <pre>{<br/>  "new_iam_role": {<br/>    "path": "/",<br/>    "permission_policy_arn_list": [],<br/>    "permission_policy_json_list": []<br/>  },<br/>  "permissions_fully_externally_managed": false<br/>}</pre> | no |
| <a name="input_existing_kms_cmk_arn"></a> [existing\_kms\_cmk\_arn](#input\_existing\_kms\_cmk\_arn) | KMS key ARN to be used to encrypt logs and sqs messages. | `string` | `null` | no |
| <a name="input_module_context"></a> [module\_context](#input\_module\_context) | Infix for the parameter store entry. If provided, must end with '/'. | `string` | `""` | no |
| <a name="input_resource_tags"></a> [resource\_tags](#input\_resource\_tags) | A map of tags to assign to the resources in this module. | `map(string)` | `{}` | no |
| <a name="input_trigger_settings"></a> [trigger\_settings](#input\_trigger\_settings) | Settings for the Lambda function's trigger settings, including permissions, SQS triggers, schedule expressions, and event rules. | <pre>object({<br/>    trigger_permissions = optional(list(object({<br/>      principal      = string<br/>      source_arn     = string<br/>      source_account = optional(string)<br/>    })), [])<br/>    sqs = optional(object({<br/>      management_permissions  = optional(list(string), []) # use sid = "ManagementPermissions" to override<br/>      access_policy_json_list = optional(list(string), [])<br/>      inbound_sns_topics = optional(list(object({<br/>        sns_arn            = string<br/>        filter_policy_json = optional(string, null)<br/>      })), [])<br/>    }), null)<br/>    schedule_expression = optional(string, null)<br/>    event_rules = optional(list(object({<br/>      name           = string<br/>      description    = optional(string, "")<br/>      event_bus_name = optional(string, "default")<br/>      event_pattern  = string<br/>    })), [])<br/>  })</pre> | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_execution_iam_role"></a> [execution\_iam\_role](#output\_execution\_iam\_role) | Information about the Lambda execution role. |
| <a name="output_lambda"></a> [lambda](#output\_lambda) | Information about the Lambda. |
| <a name="output_module_version"></a> [module\_version](#output\_module\_version) | The version of this module |
| <a name="output_trigger"></a> [trigger](#output\_trigger) | Information about the Lambda triggers. |
<!-- END_TF_DOCS -->

<!-- AUTHORS -->
## Authors

This module is maintained by [ACAI GmbH][acai-url].

<!-- LICENSE -->
## License

See [LICENSE][license-url] for full details.

<!-- COPYRIGHT -->
<br />
<p align="center">Copyright ACAI GmbH</p>

<!-- MARKDOWN LINKS & IMAGES -->
[acai-shield]: https://img.shields.io/badge/maintained_by-acai.gmbh-CB224B?style=flat
[acai-docs-shield]: https://img.shields.io/badge/documentation-docs.acai.gmbh-CB224B?style=flat
[acai-url]: https://acai.gmbh
[acai-docs-url]: https://docs.acai.gmbh
[module-version-shield]: https://img.shields.io/badge/module_version-1.6.1-CB224B?style=flat
[terraform-tested-shield]: https://img.shields.io/badge/terraform-%3E%3D1.5.7_tested-844FBA?style=flat&logo=terraform&logoColor=white
[opentofu-tested-shield]: https://img.shields.io/badge/opentofu-%3E%3D1.6_tested-FFDA18?style=flat&logo=opentofu&logoColor=black
[aws-tested-shield]: https://img.shields.io/badge/AWS-%E2%9C%93_tested-FF9900?style=flat&logo=amazonaws&logoColor=white
[aws-esc-tested-shield]: https://img.shields.io/badge/AWS_ESC-%E2%9C%93_tested-003399?style=flat&logo=amazonaws&logoColor=white
[trivy-shield]: https://img.shields.io/badge/trivy-passed-green
[checkov-shield]: https://img.shields.io/badge/checkov-passed-green
[release-shield]: https://img.shields.io/github/v/release/acai-solutions/terraform-aws-lambda?style=flat&color=success
[release-url]: https://registry.terraform.io/modules/acai-solutions/lambda/aws/latest
[license-url]: ./LICENSE
[terraform-url]: https://www.terraform.io
[aws-url]: https://aws.amazon.com
[architecture-png]: ./docs/terraform-aws-lambda.png
