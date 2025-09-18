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

import logging
import boto3
from typing import List, Dict, Optional
import globals

class AccountWrapper:
    def __init__(self, crawler_session: boto3.Session):
        self._organizations_client = crawler_session.client('organizations', config=globals.BOTO3_CONFIG_SETTINGS)
        self.accounts: List[Dict] = []
        self._load_accounts()


    def _load_accounts(self):
        logging.info('Loading all active accounts with organizations:ListAccounts API call.')

        paginator = self._organizations_client.get_paginator('list_accounts')
        for page in paginator.paginate():
            for account in page.get('Accounts', []):
                self._add_account(account)

    def _add_account(self, account_info: Dict):
        account_entry = {
            'id': account_info["Id"],
            'arn': account_info["Arn"],
            'email': account_info["Email"],
            'name': account_info["Name"],
            'status': account_info["Status"],
            'joined_method': account_info["JoinedMethod"],
            'joined_timestamp': account_info["JoinedTimestamp"]
        }
        if account_entry not in self.accounts:
            self.accounts.append(account_entry)


    def get_account_entry_by_id(self, account_id: str) -> Optional[Dict]:
        return next((account for account in self.accounts if account['id'] == account_id), None)


    def get_account_name_by_id(self, account_id: str) -> Optional[str]:
        account_entry = self.get_account_entry_by_id(account_id)
        return account_entry['name'] if account_entry else None