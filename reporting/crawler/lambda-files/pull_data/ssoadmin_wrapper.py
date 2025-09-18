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
from datetime import datetime
from typing import List, Dict, Tuple, Optional

from boto3.session import Session
import globals  # Ensure this contains BOTO3_CONFIG_SETTINGS

from pull_data.account_wrapper import AccountWrapper

class SsoAdminWrapper:
    def __init__(self, crawler_session: Session, sso_admin_instance: Optional[Dict] = None):
        self.account_wrapper = AccountWrapper(crawler_session)
        self._sso_client = crawler_session.client('sso-admin', config=globals.BOTO3_CONFIG_SETTINGS)
        
        self.instance_arn, self.identitystore_id = self._initialize_instance(sso_admin_instance)

    # ¦ _initialize_instance
    def _initialize_instance(self, instance: Optional[Dict]) -> Tuple[str, str]:
        """Fetches the first SSO instance if not provided."""
        if instance is None:
            try:
                instances_response = self._sso_client.list_instances()
                instance = instances_response.get('Instances', [{}])[0]
            except Exception as e:
                logging.error(f"Failed to list SSO instances: {e}")
                return '', ''  # Consider how you want to handle this case in your application
        
        return instance.get('InstanceArn', ''), instance.get('IdentityStoreId', '')

    # ¦ get_assignments
    def get_assignments(self, permissionsets_in_scope: Optional[List[str]] = None) -> Dict:
        """Fetches assignments for all or specified permission sets."""
        permission_sets = self._load_all_permissionsets(permissionsets_in_scope)
        for permissionset_arn, permissionset_info in permission_sets.items():
            permissionset_name = permissionset_info["permissionset_details"]["name"]
            if not permissionsets_in_scope or permissionset_name in permissionsets_in_scope:
                for account_info in permissionset_info["accounts"]:
                    account_info["assignments"] = self._get_account_assignments_for_permissionset(permissionset_arn, account_info['id'])
        return permission_sets 

    # ¦ _load_all_permissionsets
    def _load_all_permissionsets(self, permissionsets_in_scope: Optional[List[str]] = None) -> Dict:
        """Loads all permission sets, optionally filtered by scope."""
        logging.info('Retrieving all Permission Sets.')
        permission_sets = {}
        try:
            paginator = self._sso_client.get_paginator('list_permission_sets')
            for page in paginator.paginate(InstanceArn=self.instance_arn):
                for permission_set_arn in page.get('PermissionSets', []):
                    permission_set_info = self._describe_permission_set(permission_set_arn)
                    if permissionsets_in_scope is None or permission_set_info['name'] in permissionsets_in_scope:
                        accounts = self._get_accounts_for_permissionset(permission_set_arn)
                        permission_sets[permission_set_arn] = {'permissionset_details': permission_set_info, 'accounts': accounts}
        except Exception as e:
            logging.error(f"Error loading permission sets: {e}")
        return permission_sets

    # ¦ _describe_permission_set
    def _describe_permission_set(self, permission_set_arn: str) -> Dict:
        """Describes a single permission set."""
        try:
            response = self._sso_client.describe_permission_set(
                InstanceArn=self.instance_arn, PermissionSetArn=permission_set_arn)
            details = response.get('PermissionSet', {})
            return self._format_permission_set(details)
        except Exception as e:
            logging.error(f"Error describing permission set {permission_set_arn}: {e}")
            return {}

    # ¦ _format_permission_set
    def _format_permission_set(self, permission_set: Dict) -> Dict:
        """Formats permission set details for consistent output."""
        return {
            'name': permission_set.get('Name', ''),
            'arn': permission_set.get('PermissionSetArn', ''),
            'description': permission_set.get('Description', ''),
            'session_duration': permission_set.get('SessionDuration', ''),
            'relay_state': permission_set.get('RelayState', '')
        }

    # ¦ _get_accounts_for_permissionset
    def _get_accounts_for_permissionset(self, permission_set_arn: str) -> List[Dict]:
        """Fetches accounts associated with a permission set."""
        accounts = []
        try:
            paginator = self._sso_client.get_paginator('list_accounts_for_provisioned_permission_set')
            for page in paginator.paginate(InstanceArn=self.instance_arn, PermissionSetArn=permission_set_arn):
                for account_id in page.get('AccountIds', []):
                    account_info = self.account_wrapper.get_account_entry_by_id(account_id)
                    if account_info:
                        accounts.append({
                        'id': account_info.get('id'),
                        'name': account_info.get('name'),
                        'status': account_info.get('status')
                    })
            return accounts
        except Exception as e:
            logging.error(f"Error describing accounts for permission set {permission_set_arn}: {e}")
            return []

    # ¦ _get_account_assignments_for_permissionset
    def _get_account_assignments_for_permissionset(self, permission_set_arn: str, account_id: str) -> Dict[str, List[str]]:
        logging.info(f'Retrieving assignments for PermissionSet: {permission_set_arn} in Account: {account_id}')
        assignments = {'users': [], 'groups': []}

        paginator = self._sso_client.get_paginator('list_account_assignments')
        for page in paginator.paginate(InstanceArn=self.instance_arn, PermissionSetArn=permission_set_arn, AccountId=account_id):
            for assignment in page.get('AccountAssignments', []):
                principal_type = assignment.get("PrincipalType")
                principal_id = assignment.get('PrincipalId')
                if principal_type and principal_id:
                    if principal_type == 'USER':
                        assignments["users"].append(principal_id)
                    elif principal_type == 'GROUP':
                        assignments["groups"].append(principal_id)            

        return assignments

