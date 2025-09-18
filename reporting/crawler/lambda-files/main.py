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
import botocore
import boto3
from botocore.exceptions import ClientError
import os
from typing import List, Dict, Optional
import globals
from pull_data.ssoadmin_wrapper import SsoAdminWrapper
from pull_data.identitystore_wrapper import IdentitystoreWrapper
from transformer import Transformer
from rendering.csv import CSV
from rendering.excel_report import ExcelReport


REGION = os.environ["AWS_REGION"]
CRAWLER_ARN = os.environ["CRAWLER_ARN"]


def lambda_handler(event, context):
    try:
        globals.LOGGER.debug(
            f"botocore={botocore.__version__}  boto3={boto3.__version__}"
        )
        globals.LOGGER.debug(json.dumps(event))

        crawler_session = globals.assume_remote_role(
            remote_role_arn=CRAWLER_ARN, sts_region_name=REGION
        )

        ssoadmin_wrapper = SsoAdminWrapper(crawler_session)
        assignments = ssoadmin_wrapper.get_assignments()

        identitystore_wrapper = IdentitystoreWrapper(
            crawler_session, ssoadmin_wrapper.identitystore_id
        )
        identitystore_wrapper.fill_cache()

        globals.LOGGER.info(json.dumps(identitystore_wrapper.cache))

        transformer = Transformer(assignments, identitystore_wrapper)
        transformed = transformer.transform_assignments()

        reporting = ExcelReport(transformed)
        reporting.create_excel()

        reporting_csv = CSV(transformed)
        reporting_csv.render()

        return {"statusCode": 200, "body": transformed}

    except ClientError as e:
        globals.LOGGER.exception(f"Unexpected error")
        raise e
    except Exception as e:
        globals.LOGGER.exception(f"Unexpected error")
        raise e
