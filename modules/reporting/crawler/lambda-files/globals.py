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

import os
from typing import Optional

import boto3
from botocore.config import Config as boto3_config

from acai.aws_helper.boto3_client import Boto3ClientFactory
from acai.aws_helper.sts import StsClient
from acai.logging import LoggerConfig, LoggerContext, LogLevel, create_lambda_logger

LOGGER = create_lambda_logger(
    LoggerConfig(
        service_name="AWS Identity Center Reporting Crawler", log_level=LogLevel.INFO
    )
)

# Resolve region safely at import time
REGION = (
    os.environ.get("AWS_REGION")
    or os.environ.get("AWS_DEFAULT_REGION")
    or boto3.Session().region_name
    or "us-east-1"
)
REPORT_BUCKET_NAME = os.environ.get("REPORT_BUCKET_NAME")
REPORT_BUCKET_FOLDER_NAME = "idc-reports"

BOTO3_CONFIG_SETTINGS = boto3_config(
    region_name=REGION, retries=dict(max_attempts=10, mode="adaptive")
)

_CLIENT_FACTORY = Boto3ClientFactory(
    LOGGER, region=REGION, config=BOTO3_CONFIG_SETTINGS
)
_STS_CLIENT = StsClient(LOGGER)


def assume_remote_role(
    remote_role_arn: str,
    sts_region_name: Optional[str] = None,
    customer_session: Optional[boto3.Session] = None,
) -> boto3.Session:
    """Assume *remote_role_arn* and return a boto3 Session pinned to ``REGION``."""
    sts_client = (
        StsClient(LOGGER, base_session=customer_session)
        if customer_session
        else _STS_CLIENT
    )
    session = sts_client.assume_role(
        role_arn=remote_role_arn,
        region_name=sts_region_name or REGION,
        session_name="RemoteSession",
    )
    if session is None:
        raise RuntimeError(f"Was not able to assume role {remote_role_arn}")
    return session


def upload_to_s3(
    object_name: str,
    local_file_path: Optional[str] = None,
    content: Optional[bytes] = None,
):
    if not REPORT_BUCKET_NAME:
        LOGGER.info("No output bucket provided.")
        return None

    s3_bucket_name = REPORT_BUCKET_NAME
    s3_key = f"{REPORT_BUCKET_FOLDER_NAME}/{object_name}"
    s3_url = f"s3://{s3_bucket_name}/{s3_key}"

    LOGGER.info(f"Uploading to S3: {s3_url}")

    try:
        if local_file_path:
            with open(local_file_path, "rb") as file_content:
                body: bytes = file_content.read()
        elif content is not None:
            body = content
        else:
            LOGGER.error("No local file path or content provided for upload.")
            return None

        s3_client = _CLIENT_FACTORY.get_client("s3")
        s3_client.put_object(Bucket=s3_bucket_name, Key=s3_key, Body=body)

        LOGGER.info(f"Upload to S3 completed: {s3_url}")
        return s3_url
    except Exception:
        LOGGER.exception("Failed to upload to S3")
        return None
