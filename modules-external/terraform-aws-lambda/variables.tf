# ACAI AWS Lambda Module
# Copyright (C) 2024, 2025 ACAI GmbH
# Licensed under AGPL v3
#
# Visit https://www.acai.gmbh or https://docs.acai.gmbh for more information.
# 
# For full license text, see LICENSE file in repository root.


variable "lambda_settings" {
  description = "Settings for the Lambda function."
  type = object({
    function_name  = string
    description    = optional(string, "not provided")
    layer_names    = optional(list(string), null) # will be deprecated
    layer_arn_list = optional(list(string), null)
    handler        = optional(string, "main.lambda_handler")
    config = object({
      runtime                = string
      architecture           = optional(string, "x86_64")
      timeout                = optional(number, 30)
      memory_size            = optional(number, 512)
      ephemeral_storage_size = optional(number, 512)
      log_retention_in_days  = optional(number, 90)
    })
    error_handling = optional(object({
      dead_letter_config = optional(object({
        target_arn = string
      }), null)
      central_collector = optional(object({
        target_name = string
        target_arn  = string
        filter      = optional(string, "ERROR")
      }), null)
    }), null)
    package = object({
      type            = optional(string, "Zip")
      local_path      = optional(string, null)
      source_path     = optional(string, null)
      files_to_inject = optional(map(string), null) # map with path/filename as key and file-content as value
    })
    environment_variables          = optional(map(string), {})
    reserved_concurrent_executions = optional(number, -1)
    publish                        = optional(bool, false)
    tracing_mode                   = optional(string, "Active")
    file_system_config = optional(object({
      arn              = string
      local_mount_path = string
    }), null)
    image_config = optional(object({
      image_uri         = optional(string)
      command           = optional(list(string), null)
      entry_point       = optional(list(string), null)
      working_directory = optional(string, null)
    }), null)
    vpc_config = optional(object({
      security_group_ids = list(string)
      subnet_ids         = list(string)
    }), null)
  })
  validation {
    condition     = var.lambda_settings.layer_arn_list != null ? var.lambda_settings.layer_names == null : true
    error_message = "If layer_arn_list is provided, layer_names must be empty. layer_names will be deprecated."
  }
  # validation of var.lambda_settings.config
  validation {
    condition     = contains(["x86_64", "arm64"], var.lambda_settings.config.architecture)
    error_message = "Invalid architecture value. Must be either 'x86_64' or 'arm64'."
  }

  validation {
    condition     = var.lambda_settings.config.timeout >= 1 && var.lambda_settings.config.timeout <= 900
    error_message = "Timeout must be between 1 and 900 seconds."
  }
  validation {
    condition     = var.lambda_settings.config.memory_size >= 128 && var.lambda_settings.config.memory_size <= 10240 && var.lambda_settings.config.memory_size % 64 == 0
    error_message = "Memory size must be between 128 MB to 10,240 MB, in 64 MB increments."
  }

  validation {
    condition     = var.lambda_settings.config.ephemeral_storage_size >= 512 && var.lambda_settings.config.ephemeral_storage_size <= 10240
    error_message = "Ephemeral storage size must be between 512 MB to 10,240 MB."
  }

  validation {
    condition     = var.lambda_settings.config.log_retention_in_days == null || can(index([0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.lambda_settings.config.log_retention_in_days))
    error_message = "Invalid log_retention_in_days value."
  }

  # validation of var.lambda_settings.package
  validation {
    condition     = contains(["Zip", "Image"], var.lambda_settings.package.type)
    error_message = "Invalid package type. Must be either 'Zip' or 'Image'."
  }

  validation {
    condition = var.lambda_settings.package.files_to_inject == null ? true : (
      length(var.lambda_settings.package.files_to_inject) == 0 ||
      alltrue([
        for file_path in keys(var.lambda_settings.package.files_to_inject) :
        !startswith(file_path, "/")
      ])
    )
    error_message = "When provided, the keys in files_to_inject must not start with '/'."
  }
  validation {
    condition     = var.lambda_settings.tracing_mode == null ? true : contains(["Active", "PassThrough"], var.lambda_settings.tracing_mode)
    error_message = "Invalid tracing_mode value."
  }

  validation {
    condition     = var.lambda_settings.file_system_config == null || can(regex("^arn:aws(-[a-z]+)*:elasticfilesystem:", var.lambda_settings.file_system_config.arn))
    error_message = "File system config ARN must be a valid EFS ARN (arn:<partition>:elasticfilesystem:...)."
  }

  validation {
    condition     = var.lambda_settings.package.type != "Image" || (var.lambda_settings.image_config != null && var.lambda_settings.image_config != null ? var.lambda_settings.image_config.image_uri != "" : true)
    error_message = "When package type is 'Image', image_uri must be specified."
  }

  validation {
    condition     = var.lambda_settings.error_handling == null ? true : (var.lambda_settings.error_handling.dead_letter_config == null ? true : can(regex("arn:aws(-[a-z]+)*:(sns|sqs):[a-z\\-0-9]+:\\d{12}:(.*)", var.lambda_settings.error_handling.dead_letter_config.target_arn)))
    error_message = "The dead_letter_config.target_arn must be a valid ARN of an SNS topic or SQS queue."
  }

  validation {
    condition     = can(length(var.lambda_settings.vpc_config.security_group_ids)) && can(length(var.lambda_settings.vpc_config.subnet_ids)) ? (length(var.lambda_settings.vpc_config.security_group_ids) > 0 && length(var.lambda_settings.vpc_config.subnet_ids) > 0) : true
    error_message = "Both security_group_ids and subnet_ids must be provided for VPC configuration."
  }

  validation {
    condition     = can(length(var.lambda_settings.vpc_config.security_group_ids)) && can(length(var.lambda_settings.vpc_config.subnet_ids)) ? (length(var.lambda_settings.vpc_config.security_group_ids) > 0 && length(var.lambda_settings.vpc_config.subnet_ids) > 0) : true
    error_message = "Both security_group_ids and subnet_ids must be provided for VPC configuration."
  }
}

variable "trigger_settings" {
  description = "Settings for the Lambda function's trigger settings, including permissions, SQS triggers, schedule expressions, and event rules."
  type = object({
    trigger_permissions = optional(list(object({
      principal      = string
      source_arn     = string
      source_account = optional(string)
    })), [])
    sqs = optional(object({
      management_permissions  = optional(list(string), []) # use sid = "ManagementPermissions" to override
      access_policy_json_list = optional(list(string), [])
      inbound_sns_topics = optional(list(object({
        sns_arn            = string
        filter_policy_json = optional(string, null)
      })), [])
    }), null)
    schedule_expression = optional(string, null)
    event_rules = optional(list(object({
      name           = string
      description    = optional(string, "")
      event_bus_name = optional(string, "default")
      event_pattern  = string
    })), [])
  })
  default = {}

  validation {
    condition = alltrue([
      for perm in try(var.trigger_settings.trigger_permissions, []) :
      can(regex(".+\\.amazonaws\\.com$|^\\d{12}$", perm.principal)) && can(regex("^arn:aws(-[a-z]+)*:.+|^any$", perm.source_arn))
    ])
    error_message = "Invalid trigger_permissions configuration. Principals must be AWS service principals or AWS account IDs, and Source ARNs must start with 'arn:aws:' or be 'any'."
  }

  validation {
    condition     = try(length(var.trigger_settings.sqs.access_policy_json_list) > 0, false) ? alltrue([for json_str in var.trigger_settings.sqs.access_policy_json_list : can(jsondecode(json_str))]) : true
    error_message = "Each item in the SQS access policy JSON list must be a valid JSON string."
  }

  validation {
    condition     = try(var.trigger_settings.sqs != null && length(var.trigger_settings.sqs.inbound_sns_topics) > 0, false) ? alltrue([for topic in var.trigger_settings.sqs.inbound_sns_topics : can(jsondecode(topic.filter_policy_json)) || topic.filter_policy_json == null]) : true
    error_message = "Each filter_policy_json in the SQS inbound SNS topics must be a valid JSON string or null."
  }

  validation {
    condition = can(var.trigger_settings.sqs) && alltrue([
      for topic in try(var.trigger_settings.sqs.inbound_sns_topics, []) :
      can(regex("^arn:aws(-[a-z]+)*:sns:", topic.sns_arn))
    ])
    error_message = "Values for trigger_settings.sqs.inbound_sns_topics must contain a valid SNS ARN (arn:<partition>:sns:...)."
  }

  validation {
    condition = try(var.trigger_settings.schedule_expression != null, false) ? (
      can(regex("^(rate\\([1-9]\\d*\\s+(minute|minutes|hour|hours|day|days)\\))$", try(var.trigger_settings.schedule_expression, ""))) ||
      can(regex("^cron\\((\\S+\\s+){5,6}\\S+\\)$", try(var.trigger_settings.schedule_expression, "")))
    ) : true
    error_message = "The schedule_expression must be either a valid rate expression (e.g., 'rate(5 minutes)') or a cron expression (e.g., 'cron(0 20 * * ? *)')."
  }

  validation {
    condition = alltrue([
      for rule in try(var.trigger_settings.event_rules, []) :
      can(jsondecode(rule.event_pattern)) && can(jsondecode(rule.event_pattern)["source"])
    ])
    error_message = "Values for event_rules must be valid JSON and include a 'source' field."
  }
}

variable "execution_iam_role_settings" {
  description = "Settings of the for Lambda execution IAM role."
  type = object({
    new_iam_role = optional(object({
      name                        = optional(string)
      path                        = optional(string, "/")
      permissions_boundary_arn    = optional(string)
      permission_policy_arn_list  = optional(list(string), [])
      permission_policy_json_list = optional(list(string), [])
    }), null)
    existing_iam_role_arn                = optional(string, null)
    permissions_fully_externally_managed = optional(bool, false)
  })
  default = {
    new_iam_role = {
      path                        = "/"
      permission_policy_arn_list  = []
      permission_policy_json_list = []
    }
    permissions_fully_externally_managed = false
  }
  validation {
    condition = (
      (var.execution_iam_role_settings.new_iam_role != null && var.execution_iam_role_settings.existing_iam_role_arn == null) ||
      (var.execution_iam_role_settings.new_iam_role == null && var.execution_iam_role_settings.existing_iam_role_arn != null)
    )
    error_message = "Specify exactly one of 'new_role' or 'existing_iam_role_arn'."
  }
}

variable "existing_kms_cmk_arn" {
  description = "KMS key ARN to be used to encrypt logs and sqs messages."
  type        = string
  default     = null
  validation {
    condition     = var.existing_kms_cmk_arn == null ? true : can(regex("^arn:aws(-[a-z]+)*:kms", var.existing_kms_cmk_arn))
    error_message = "Value must be a valid KMS ARN (arn:<partition>:kms:...)."
  }
}

variable "resource_tags" {
  description = "A map of tags to assign to the resources in this module."
  type        = map(string)
  default     = {}
}

variable "module_context" {
  description = "Infix for the parameter store entry. If provided, must end with '/'."
  type        = string
  default     = ""
  validation {
    condition     = var.module_context == "" || endswith(var.module_context, "/")
    error_message = "If module_context is provided, it must end with '/'."
  }
}
