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
from typing import List, Dict, Optional
from pull_data.identitystore_wrapper import IdentitystoreWrapper

class Transformer:
    def __init__(self, permission_sets: Dict, identitystore_wrapper: IdentitystoreWrapper):
        self.permission_sets = permission_sets
        self.identitystore_wrapper = identitystore_wrapper

    def transform_assignments(self) -> Dict:
        """
        Transforms the structured permission set and account assignments into a nested dictionary format.
        This includes an accounts section detailing each account's permission sets, users, and groups.
        The principals section is a concatenation of all unique users and groups across accounts.

        Args:
            permission_sets (Dict): The original permission sets data structure.
            identitystore_wrapper (IdentitystoreWrapper): Wrapper to fetch display names for users and groups.

        Returns:
            Dict: The transformed data structure organized by account IDs, including principals info.
        """
        # Initialize the structure for transformed data
        transformed = {"accounts": {}, "principals": {"users": {}, "groups": {}}}
        referenced_user_ids = []
        referenced_group_ids = []

        for ps_arn, ps_info in self.permission_sets.items():
            for account in ps_info.get("accounts", []):
                account_id = account.get("id")
                account_name = account.get("name")
                account_status = account.get("status")

                # Fetch user and group display names
                user_ids = account.get("assignments", {}).get("users", [])
                group_ids = account.get("assignments", {}).get("groups", [])

                # Add unique user_ids to referenced_user_ids
                new_user_ids = [user_id for user_id in user_ids if user_id not in referenced_user_ids]
                referenced_user_ids.extend(new_user_ids)
                # Similarly, add unique group_ids to referenced_group_ids
                new_group_ids = [group_id for group_id in group_ids if group_id not in referenced_group_ids]
                referenced_group_ids.extend(new_group_ids)

                # Initialize or update the account info in the transformed dict
                if account_id not in transformed["accounts"]:
                    transformed["accounts"][account_id] = {
                        "account_name": account_name,
                        "account_status": account_status,
                        "permission_sets": {
                            ps_info["permissionset_details"]["name"]: {
                                "permission_set_arn": ps_arn,
                                "users": user_ids,
                                "groups":group_ids
                            }                        
                        }
                    }
                else:
                    # If the account is already in the transformed dict, just update with new permission set info
                    transformed["accounts"][account_id]["permission_sets"][ps_info["permissionset_details"]["name"]] = {
                        "permission_set_arn": ps_arn,
                        "users": user_ids,
                        "groups": group_ids
                    }
                    
        for group_id in referenced_group_ids:
            group_info = self.identitystore_wrapper.get_group_info(group_id)
            assigned_user_ids = group_info["assigned_users"]
            # Populate the groups within principals with display names and assigned users
            transformed["principals"]["groups"][group_id] = group_info
            # Ensure all users found as part of group memberships are also referenced
            for user_id in assigned_user_ids:
                if user_id not in referenced_user_ids:
                    referenced_user_ids.append(user_id)    
                    
        # Now, fetch and add user details for all referenced users
        for user_id in referenced_user_ids:
            if isinstance(user_id, str):
                user_info = self.identitystore_wrapper.get_user_info(user_id)
                # Populate the users within principals with display names
                transformed["principals"]["users"][user_id] = user_info
            else:
                logging.error(f"Expected string for user_id, got {type(user_id)}: {user_id}")
            
        return transformed
