# Identity Center Reporting

This sub-module provides two folders:

- principal: to be provisioned in the IdC Management Account
- module: contains the Lambda for crawling the AWS IdC instance

Output of the Lambda:

``` json
{
  "accounts" : {
    "{account1_id}": {
        "account_name": "Account One",
        "account_status": "active",
        "permission_sets": {
          "{permission_set1_name}": {
            "permission_set_arn": "arn:aws:iam::123456789012:permission-set/ssoins-12345678/ps-12345678",
            "users": ["{user1_id}", "{user2_id}"],
            "groups": ["{group1_id}"]
          }
        }
    },
    "{account2_id}": {
        "account_name": "Account Two",
        "account_status": "active",
        "permission_sets": {
          "{permission_set1_name}": {
            "permission_set_arn": "arn:aws:iam::123456789012:permission-set/ssoins-12345678/ps-12345678",
            "users": [],
            "groups": ["{group1_id}"]
          },
          "{permission_set2_name}": {
            "permission_set_arn": "arn:aws:iam::210987654321:permission-set/ssoins-87654321/ps-87654321",
            "users": ["{user2_id}"],
            "groups": ["{group2_id}"]
          }
      }
    }
  },
  "principals": {
    "groups": {
      "{group1_id}": {
        "group_display_name": "Developers",
        "assigned_users": ["{user1_id}", "{user2_id}"]
      },
      "{group2_id}": {
        "group_display_name": "Admins",
        "assigned_users": ["{user1_id}"]
      }
    },
    "users": {
      "{user1_id}":  {
          "user_name": "john.doe@acai.gmbh",
          "display_name": "John Doe"
        },
      "{user2_id}": {
          "user_name": "jane.doe@acai.gmbh",
          "display_name": "Jane Doe"
        }
    }
  }
}
```
