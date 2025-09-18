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

from datetime import datetime
from io import StringIO
import csv
import globals

class CSV:
    def __init__(self, transformed):
        self.transformed = transformed

    def render(self):
        timestamp  = datetime.now().strftime("%Y%m%d_%H%M%S")
        
        # Assignments file
        object_name_assignments = f'{timestamp}_assignments.csv'
        assignments_content = StringIO()
        csv_writer_assignments = csv.writer(assignments_content)
        csv_writer_assignments.writerow(['account_id', 'account_name', 'permission_set_name', 'group_id', 'user_id'])

        # Iterate through accounts for assignments
        for account_id, account_info in self.transformed['accounts'].items():
            for permission_set_name, permission_set_info in account_info['permission_sets'].items():
                for group_id in permission_set_info['groups']:
                    for user_id in self.transformed['principals']['groups'][group_id]['assigned_users']:
                        csv_writer_assignments.writerow([account_id, account_info['account_name'], permission_set_name, group_id, user_id])

        # Lookup files for Users
        user_object_name_lookup = f'{timestamp}_user_lookup.csv'
        user_lookup_content = StringIO()
        csv_writer_user_lookup = csv.writer(user_lookup_content)
        csv_writer_user_lookup.writerow(['principal_id', 'display_name', 'user_name'])
        # Populate lookup CSV with users
        for user_id, user_details in self.transformed['principals']['users'].items():
            csv_writer_user_lookup.writerow([user_id, 'User', user_details.get('display_name', ''), user_details.get('user_name', '')])

        # Lookup files for Groups
        group_object_name_lookup = f'{timestamp}_group_lookup.csv'
        group_lookup_content = StringIO()
        csv_writer_group_lookup = csv.writer(group_lookup_content)
        csv_writer_group_lookup.writerow(['principal_id', 'display_name', 'external_id_0', 'external_id_issuer_0'])
        # Populate group CSV with groups and their details
        for group_id, group_details in self.transformed['principals']['groups'].items():
            display_name = group_details.get('display_name', '')
            external_ids = group_details.get('external_ids', [])
            
            # Assuming at least one external_id exists and taking the first one as an example
            external_id_0 = external_ids[0]['id'] if external_ids else ''
            external_id_issuer_0 = external_ids[0]['issuer'] if external_ids else ''
            
            csv_writer_group_lookup.writerow([group_id, display_name, external_id_0, external_id_issuer_0])
                    
        # Save to S3
        globals.upload_to_s3(object_name = object_name_assignments, content = assignments_content.getvalue())
        globals.upload_to_s3(object_name = user_object_name_lookup, content = user_lookup_content.getvalue())
        globals.upload_to_s3(object_name = group_object_name_lookup, content = group_lookup_content.getvalue())
