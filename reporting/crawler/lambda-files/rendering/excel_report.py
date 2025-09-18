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
import tempfile
from datetime import datetime

import globals
import xlsxwriter


class ExcelReport:
    def __init__(self, transformed):
        self.transformed = transformed

    def create_excel(self):
        # Generate the timestamp for file naming
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        file_name = f"{timestamp}_assignments.xlsx"
        # local_file_path = f"/tmp/{file_name}"
        local_file_path = os.path.join(tempfile.gettempdir(), file_name)

        # Create the Excel workbook and the first worksheet
        workbook = xlsxwriter.Workbook(local_file_path)
        worksheet_assignments = workbook.add_worksheet("Assignments")

        # Define header format and write headers for the first sheet
        header_format = workbook.add_format(
            {
                "bold": True,
                "align": "center",
                "valign": "vcenter",
                "bg_color": "#D3D3D3",
            }
        )
        headers_assignments = [
            "Account-ID",
            "Account-Name",
            "PermSet-Name",
            "Group-Name",
            "User-Name",
            "User-Display-Name",
            "Group-ID",
            "User-ID",
        ]

        for col_num, header in enumerate(headers_assignments):
            worksheet_assignments.write(0, col_num, header, header_format)

        # Set column widths and freeze the header row for the first sheet
        worksheet_assignments.set_column("A:A", 20)  # Account-ID
        worksheet_assignments.set_column("B:B", 30)  # Account-Name
        worksheet_assignments.set_column("C:C", 30)  # PermSet-Name
        worksheet_assignments.set_column("D:D", 30)  # Group-Name
        worksheet_assignments.set_column("E:E", 30)  # User-Name
        worksheet_assignments.set_column("F:F", 30)  # User-Display-Name
        worksheet_assignments.set_column("G:G", 50)  # Group-ID
        worksheet_assignments.set_column("H:H", 50)  # User-ID
        worksheet_assignments.freeze_panes(1, 0)
        worksheet_assignments.autofilter(
            0, 0, 0, len(headers_assignments) - 1
        )  # Apply filter to the header row

        # Write data to the first worksheet
        row_num = 1  # Start after the header row
        for account_id, account_info in self.transformed["accounts"].items():
            for permission_set_name, permission_set_info in account_info[
                "permission_sets"
            ].items():
                # Group-based assignments
                for group_id in permission_set_info["groups"]:
                    group_details = self.transformed["principals"]["groups"].get(
                        group_id, {}
                    )
                    group_name = group_details.get("display_name", f"Group-{group_id}")

                    for user_id in group_details.get("assigned_users", []):
                        user_details = self.transformed["principals"]["users"].get(
                            user_id, {}
                        )
                        user_name = user_details.get("user_name", f"User-{user_id}")
                        user_display_name = user_details.get(
                            "display_name", f"User-{user_id}"
                        )
                        worksheet_assignments.write_row(
                            row_num,
                            0,
                            [
                                account_id,
                                account_info["account_name"],
                                permission_set_name,
                                group_name,
                                user_name,
                                user_display_name,
                                group_id,
                                user_id,
                            ],
                        )
                        row_num += 1

                # Direct user assignments (no group)
                for user_id in permission_set_info.get("users", []):
                    user_details = self.transformed["principals"]["users"].get(
                        user_id, {}
                    )
                    user_name = user_details.get("user_name", f"User-{user_id}")
                    user_display_name = user_details.get(
                        "display_name", f"User-{user_id}"
                    )
                    worksheet_assignments.write_row(
                        row_num,
                        0,
                        [
                            account_id,
                            account_info["account_name"],
                            permission_set_name,
                            "",
                            user_name,
                            user_display_name,
                            "",
                            user_id,
                        ],
                    )
                    row_num += 1

        # Add the second worksheet for group and user summary
        worksheet_group_user = workbook.add_worksheet("Group-User Summary")
        headers_summary = ["Group-Name", "User-Name", "Group-ID", "User-ID"]

        for col_num, header in enumerate(headers_summary):
            worksheet_group_user.write(0, col_num, header, header_format)

        worksheet_group_user.set_column("A:A", 30)  # Group-Name
        worksheet_group_user.set_column("B:B", 30)  # User-Name
        worksheet_group_user.set_column("C:C", 30)  # User-Display-Name
        worksheet_group_user.set_column("D:D", 50)  # Group-ID
        worksheet_group_user.set_column("E:E", 50)  # User-ID
        worksheet_group_user.freeze_panes(1, 0)

        # Write data to the second worksheet
        row_num = 1  # Start after the header row
        for group_id, group_info in self.transformed["principals"]["groups"].items():
            group_name = group_info.get("display_name", f"Group-{group_id}")
            for user_id in group_info.get("assigned_users", []):
                user_details = self.transformed["principals"]["users"].get(user_id, {})
                user_name = user_details.get("user_name", f"User-{user_id}")
                user_display_name = user_details.get("display_name", f"User-{user_id}")
                worksheet_group_user.write_row(
                    row_num,
                    0,
                    [group_name, user_name, user_display_name, group_id, user_id],
                )
                row_num += 1

        # Close the workbook after writing all data
        workbook.close()

        # Log and upload the file to S3
        file_size = os.path.getsize(local_file_path)
        globals.LOGGER.info(
            f"Local Excel created. File size: {file_size / (1024 * 1024):.2f} MB"
        )
        globals.upload_to_s3(object_name=file_name, local_file_path=local_file_path)
