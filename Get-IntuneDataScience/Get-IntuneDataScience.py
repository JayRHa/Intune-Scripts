"""
Get-IntuneDataScience: Fetch Intune managed device data from Microsoft Graph API
and generate an exploratory data analysis report using Sweetviz.

Requires TENANT_ID environment variable. Optionally set CLIENT_ID.
Authenticates via device code flow (interactive).
"""

import os
import sys

from msal import PublicClientApplication
import requests
import json
import sweetviz as sv
import pandas as pd

# Configuration from environment variables
TENANT_ID = os.environ.get("TENANT_ID", "")
CLIENT_ID = os.environ.get("CLIENT_ID", "14d82eec-204b-4c2f-b7e8-296a70dab67e")
ENDPOINT = 'deviceManagement/managedDevices'

AUTHORITY = f'https://login.microsoftonline.com/{TENANT_ID}'
SCOPES = ['DeviceManagementManagedDevices.Read.All']


def main():
    """Main entry point for Intune data science report generation."""
    if not TENANT_ID:
        raise ValueError("TENANT_ID environment variable is required")

    app = PublicClientApplication(CLIENT_ID, authority=AUTHORITY)

    flow = app.initiate_device_flow(scopes=SCOPES)
    if 'user_code' not in flow:
        raise ValueError('Fail to create device flow. Err: %s' % json.dumps(flow, indent=4))
    print(flow['message'])

    result = app.acquire_token_by_device_flow(flow)

    if 'access_token' in result:
        graph_api_endpoint = f'https://graph.microsoft.com/beta/{ENDPOINT}'
        access_token = result['access_token']
    else:
        print("No access token in result. Error: %s" % result.get("error"), file=sys.stderr)
        raise ValueError('No access token in result')

    headers = {
        'Authorization': 'Bearer ' + access_token,
        'Content-Type': 'application/json'
    }

    try:
        # Fetch all pages of results
        all_values = []
        url = graph_api_endpoint
        while url:
            response = requests.get(url, headers=headers)
            response.raise_for_status()
            data = response.json()
            all_values.extend(data.get('value', []))
            url = data.get('@odata.nextLink')

        df = pd.DataFrame(all_values)

        # Prepare dataset: parse datetime columns
        df['enrolledDateTime'] = pd.to_datetime(df['enrolledDateTime'])
        df['lastSyncDateTime'] = pd.to_datetime(df['lastSyncDateTime'])

        # Extract serial number from nested hardwareInformation dict
        if 'hardwareInformation' in df.columns and df['hardwareInformation'].apply(lambda x: isinstance(x, dict)).any():
            df['serialNumber'] = df['hardwareInformation'].apply(
                lambda x: x.get('serialNumber') if isinstance(x, dict) else None
            )
        else:
            print("Column 'hardwareInformation' does not exist or does not contain dictionaries")

        # Convert list/dict columns to strings so Sweetviz can handle them,
        # but fill NaN first to avoid converting None to the string "None"
        for col in df.columns:
            if df[col].apply(lambda x: isinstance(x, (list, dict))).any():
                df[col] = df[col].fillna("").apply(
                    lambda x: str(x) if isinstance(x, (list, dict)) else x
                )

        report = sv.analyze(df)
        report.show_html('Sweetviz_Report.html')
        print("Report generated: Sweetviz_Report.html")

    except requests.exceptions.HTTPError as e:
        print(f"HTTP error while calling Graph API: {e}", file=sys.stderr)
        raise
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        raise


if __name__ == "__main__":
    main()
