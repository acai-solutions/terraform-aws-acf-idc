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
import boto3
from botocore.config import Config as boto3_config
import logging
from typing import Optional
LOGLEVEL = os.environ.get('LOG_LEVEL', 'INFO').upper()
logging.getLogger().setLevel(LOGLEVEL)
for noisy_log_source in ['boto', 'boto3', 'botocore', 'urllib3']:
    logging.getLogger(noisy_log_source).setLevel(logging.WARN)
LOGGER = logging.getLogger()

REGION = os.environ['AWS_REGION']
REPORT_BUCKET_NAME = os.environ['REPORT_BUCKET_NAME']
REPORT_BUCKET_FOLDER_NAME = 'idc-reports'

BOTO3_CONFIG_SETTINGS = boto3_config(
    region_name = REGION,
    retries = dict(
        max_attempts = 10,
        mode = 'adaptive'
    )
)

def assume_remote_role(remote_role_arn, sts_region_name = None, customer_session = None):
    try:
        """Assumes the provided role in the auditing member account and returns a session"""

        # Beginning the assume role process for account
        sts_client = None
        if sts_region_name is None:
            if customer_session is None:
                sts_client = boto3.client('sts')
            else:
                sts_client = customer_session.client('sts')
        else:
            if customer_session is None:
                sts_client = boto3.client('sts', region_name = sts_region_name)
            else:
                sts_client = customer_session.client('sts', region_name = sts_region_name)

        LOGGER.debug(f"Assuming role {remote_role_arn}")
        response = sts_client.assume_role(
            RoleArn=remote_role_arn,
            RoleSessionName='RemoteSession'
        )

        # Storing STS credentials
        session = boto3.Session(
            aws_access_key_id=response['Credentials']['AccessKeyId'],
            aws_secret_access_key=response['Credentials']['SecretAccessKey'],
            aws_session_token=response['Credentials']['SessionToken']
        )
        LOGGER.debug(f"Assumed role {remote_role_arn}")
        return session

    except Exception as e:
        LOGGER.exception(f"Was not able to assume role {remote_role_arn}")
        return None

def upload_to_s3(object_name: str, local_file_path: Optional[str] = None, content: Optional[bytes] = None):
    if REPORT_BUCKET_NAME:
        s3_client = boto3.client('s3')
        s3_bucket_name = REPORT_BUCKET_NAME
        s3_key = f"{REPORT_BUCKET_FOLDER_NAME}/{object_name}"
        s3_url = f"s3://{s3_bucket_name}/{s3_key}"
        
        LOGGER.info(f"Uploading to S3: {s3_url}")
        
        try:
            if local_file_path:
                with open(local_file_path, 'rb') as file_content:
                    s3_client.put_object(
                        Bucket=s3_bucket_name,
                        Key=s3_key,
                        Body=file_content
                    )
            elif content is not None:
                s3_client.put_object(
                    Bucket=s3_bucket_name,
                    Key=s3_key,
                    Body=content
                )
            else:
                LOGGER.error("No local file path or content provided for upload.")
                return None
            
            LOGGER.info(f"Upload to S3 completed: {s3_url}")
            return s3_url
        except Exception as e:
            LOGGER.error(f"Failed to upload to S3: {e}")
            return None
    else:
        LOGGER.info("No output bucket provided.")
        return None    