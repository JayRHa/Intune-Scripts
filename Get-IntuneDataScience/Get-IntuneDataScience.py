from msal import PublicClientApplication
import requests
import json
import sweetviz as sv
import pandas as pd

# Define the Tenant Id and your endpoint
TENANT_ID = ''
ENDPOINT = 'deviceManagement/managedDevices'


CLIENT_ID = '14d82eec-204b-4c2f-b7e8-296a70dab67e'
AUTHORITY = f'https://login.microsoftonline.com/{TENANT_ID}'
SCOPES = ['DeviceManagementManagedDevices.Read.All'] 


app = PublicClientApplication(CLIENT_ID, authority=AUTHORITY)

flow = app.initiate_device_flow(scopes=SCOPES)
if 'user_code' not in flow:
    raise ValueError('Fail to create device flow. Err: %s' % json.dumps(flow, indent=4))
print(flow['message'])

result = app.acquire_token_by_device_flow(flow)  # This will block until the user authenticates or the flow times out

if 'access_token' in result:
    graph_api_endpoint = f'https://graph.microsoft.com/beta/{ENDPOINT}'
    access_token = result['access_token']
else:
    print("No access token in result. Error: %s" % result.get("error"))
    raise ValueError('No access token in result')

headers = {
    'Authorization': 'Bearer ' + access_token,
    'Content-Type': 'application/json'
}

try:
    response = requests.get(graph_api_endpoint, headers=headers)
    data = response.json()
    df = pd.DataFrame(data['value'])

    # HERE YOU CAN PREPARE YOUR DATASET AND EXTRACT VALUES FROM JSON OR LISTS
    df['enrolledDateTime'] = pd.to_datetime(df['enrolledDateTime'])
    df['lastSyncDateTime'] = pd.to_datetime(df['lastSyncDateTime'])
    if 'hardwareInformation' in df.columns and df['hardwareInformation'].apply(lambda x: isinstance(x, dict)).any():
        df['serialNumber'] = df['hardwareInformation'].apply(lambda x: x.get('serialNumber') if isinstance(x, dict) else None).astype(str)
    else:
        print("Column 'hardwareInformation' does not exist or does not contain dictionaries")


    for col in df.columns:
        if df[col].apply(lambda x: isinstance(x, list)).any():
            df[col] = df[col].astype(str)
        if df[col].apply(lambda x: isinstance(x, dict)).any():
            df[col] = df[col].astype(str)

    report = sv.analyze(df)
    report.show_html('Sweetviz_Report.html')

except Exception as e:
    print(e)
    raise ValueError('Something went wrong while calling graph or processing data')
