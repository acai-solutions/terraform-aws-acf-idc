"""
ACAI Cloud Foundation (ACF)
Copyright (C) 2025 ACAI GmbH
Licensed under AGPL v3
#
This file is part of ACAI ACF.
Visit https://www.acai.gmbh or https://docs.acai.gmbh for more information.

For full license text, see LICENSE file in repository root.
For commercial licensing, contact: contact@acai.gmbh


"""

import json
import os

import boto3
import botocore
import globals
from botocore.exceptions import ClientError
from pull_data.identitystore_wrapper import IdentitystoreWrapper
from pull_data.ssoadmin_wrapper import SsoAdminWrapper
from rendering.csv import CSV
from rendering.excel_report import ExcelReport
from transformer import Transformer


def lambda_handler(event, context):
    try:
        # Minimal, safe startup logs
        globals.LOGGER.debug(
            f"botocore={botocore.__version__} boto3={boto3.__version__}"
        )
        if isinstance(event, dict):
            globals.LOGGER.debug(f"Event keys: {list(event.keys())}")

        region = os.environ.get("AWS_REGION")
        crawler_arn = os.environ.get("CRAWLER_ARN")
        if not region or not crawler_arn:
            globals.LOGGER.error(
                "Missing required environment variables: AWS_REGION and/or CRAWLER_ARN"
            )
            return {
                "statusCode": 500,
                "body": json.dumps({"error": "Server misconfiguration"}),
            }

        crawler_session = globals.assume_remote_role(
            remote_role_arn=crawler_arn, sts_region_name=region
        )

        ssoadmin_wrapper = SsoAdminWrapper(crawler_session)
        assignments = ssoadmin_wrapper.get_assignments()

        identitystore_wrapper = IdentitystoreWrapper(
            crawler_session, ssoadmin_wrapper.identitystore_id
        )
        identitystore_wrapper.fill_cache()

        # Avoid dumping full cache to logs; log only sizes at debug level
        try:
            users_count = len(identitystore_wrapper.cache.get("users", {}))
            groups_count = len(identitystore_wrapper.cache.get("groups", {}))
            globals.LOGGER.debug(
                f"Identity cache sizes: users={users_count}, groups={groups_count}"
            )
        except Exception:
            globals.LOGGER.debug("Identity cache size check failed")

        transformer = Transformer(assignments, identitystore_wrapper)
        transformed = transformer.transform_assignments()

        reporting = ExcelReport(transformed)
        reporting.create_excel()

        reporting_csv = CSV(transformed)
        reporting_csv.render()

        return {"statusCode": 200, "body": json.dumps(transformed)}

    except ClientError:
        globals.LOGGER.exception("AWS client error")
        raise
    except Exception:
        globals.LOGGER.exception("Unhandled error")
        raise
