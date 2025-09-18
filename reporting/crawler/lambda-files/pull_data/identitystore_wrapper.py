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

class IdentitystoreWrapper:
    def __init__(self, crawler_session: boto3.Session, identitystore_id: str):
        """
        Initializes the wrapper with a boto3 Identity Store client and store ID.

        Args:
            boto3_identitystore_client: The boto3 client for AWS Identity Store.
            identitystore_id (str): The ID of the AWS Identity Store.
        """
        self._identitystore_client = crawler_session.client('identitystore', config=globals.BOTO3_CONFIG_SETTINGS)
        self._identitystore_id = identitystore_id
        self.cache = {'users': {}, 'groups': {}}

    # ¦ fill_cache
    def fill_cache(self):
        logging.info("Pre-populating users and groups cache.")
        self._fill_user_cache()
        self._fill_group_cache()
        
#region user_info
    # ¦ get_user_info
    def get_user_info(self, user_id: str) -> Optional[Dict]:
        user_info = {'user_name': 'n/a', 'display_name': 'n/a'}
        if not isinstance(user_id, str):
            logging.error(f"Expected string for user_id, got {type(user_id)}: {user_id}")
            return user_info
    
        if user_id in self.cache['users']:
            return self.cache['users'][user_id]
        
        try:
            user_info_boto3 = self._identitystore_client.describe_user(
                IdentityStoreId=self._identitystore_id, 
                UserId=user_id
            )
            self.cache['users'][user_id] = self._extract_user_info(user_info_boto3)
            return user_info
        except Exception as e:
            logging.error(f'Error fetching user {user_id}: {e}')
            return user_info

    def _extract_user_info(self, user_info: Dict) -> Dict:
        return {
            'user_name': user_info.get('UserName', 'n/a'),
            'display_name': user_info.get('DisplayName', 'n/a')
        }

    # ¦ _fill_user_cache
    def _fill_user_cache(self):
        logging.info("Fetching all users.")
        try:
            paginator = self._identitystore_client.get_paginator('list_users')
            for page in paginator.paginate(IdentityStoreId=self._identitystore_id):
                for user in page['Users']:
                    self.cache['users'][user['UserId']] = self._extract_user_info(user)
        except Exception as e:
            logging.error(f"Failed to fetch users: {e}")
#endregion

#region group_info
    # ¦ get_group_info
    def get_group_info(self, group_id: str) -> Optional[Dict]:
        group_info = {
            'display_name': 'n/a', 
            'user_ids':  [] , 
            'external_ids':  [] 
        }
        if not isinstance(group_id, str):
            logging.error(f"Expected string for group_id, got {type(group_id)}: {group_id}")
            return group_info
            
        if group_id in self.cache['groups']:
            return self.cache['groups'][group_id]
        
        try:
            response = self._identitystore_client.describe_group(IdentityStoreId=self._identitystore_id, GroupId=group_id)
            external_ids_transformed = [
                {'issuer': external_id.get('Issuer'), 'id': external_id.get('Id')}
                for external_id in response.get('ExternalIds', [])
            ]            
            group_info = {
                'display_name': response.get('DisplayName'),
                'assigned_users': self._list_group_memberships(group_id),
                'external_ids': external_ids_transformed
            }
            self.cache['groups'][group_id] = group_info
            return group_info
        except Exception as e:
            logging.error(f'Error fetching group {group_id}: {e}')
            return group_info
        
    # ¦ _fill_group_cache
    def _fill_group_cache(self):
        logging.info("Fetching all groups.")
        try:
            paginator = self._identitystore_client.get_paginator('list_groups')
            for page in paginator.paginate(IdentityStoreId=self._identitystore_id):
                for group in page['Groups']:
                    self.get_group_info(group['GroupId'])
        except Exception as e:
            logging.error(f"Failed to fetch groups: {e}")

    # ¦ _list_group_memberships
    def _list_group_memberships(self, group_id: str) -> List[str]:
        user_ids = []
        try:
            paginator = self._identitystore_client.get_paginator('list_group_memberships')
            for page in paginator.paginate(IdentityStoreId=self._identitystore_id, GroupId=group_id):
                for group_membership in page.get('GroupMemberships', []):
                    # Corrected the path to access 'MemberId' as it's directly available
                    user_id = group_membership.get("MemberId", {}).get("UserId")
                    if user_id:
                        user_ids.append(user_id)

        except Exception as error:
            logging.error(f'Error reading group members for {group_id} at {self._identitystore_id}: {error}')

        return user_ids
#endregion
