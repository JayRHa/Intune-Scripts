"""
Ime-LogSummarizerRemote: Collect Intune Management Extension logs from a remote
device via Microsoft Graph API, download them, and summarize errors/issues
using Azure OpenAI (GPT-4o).

Requires environment variables:
  CLIENT_ID        - Azure AD app registration client ID
  TENANT_ID        - Azure AD tenant ID
  CLIENT_SECRET    - Azure AD app registration client secret
  OPEN_AI_API_KEY  - Azure OpenAI API key
  OPEN_AI_ENDPOINT - Azure OpenAI endpoint URL
  DEVICE_ID        - Intune managed device ID
"""

import os
import urllib.request
import zipfile
import sys

import requests
import msal
from openai import AzureOpenAI
from loguru import logger

CLIENT_ID = os.environ.get("CLIENT_ID", "")
TENANT_ID = os.environ.get("TENANT_ID", "")
CLIENT_SECRET = os.environ.get("CLIENT_SECRET", "")

OPEN_AI_API_KEY = os.environ.get("OPEN_AI_API_KEY", "")
OPEN_AI_ENDPOINT = os.environ.get("OPEN_AI_ENDPOINT", "")

DEVICE_ID = os.environ.get("DEVICE_ID", "")

MAX_LOG_CHARS = 128000


def _check_required_env_vars():
    """Validate that all required environment variables are set."""
    required = {
        "CLIENT_ID": CLIENT_ID,
        "TENANT_ID": TENANT_ID,
        "CLIENT_SECRET": CLIENT_SECRET,
        "OPEN_AI_API_KEY": OPEN_AI_API_KEY,
        "OPEN_AI_ENDPOINT": OPEN_AI_ENDPOINT,
        "DEVICE_ID": DEVICE_ID,
    }
    missing = [name for name, value in required.items() if not value]
    if missing:
        raise ValueError(
            f"Missing required environment variables: {', '.join(missing)}"
        )


def get_access_token(client_id, client_secret, tenant_id):
    """Get an access token for the Microsoft Graph API using client credentials."""
    authority = f"https://login.microsoftonline.com/{tenant_id}"
    app = msal.ConfidentialClientApplication(
        client_id,
        authority=authority,
        client_credential=client_secret,
    )
    result = app.acquire_token_for_client(
        scopes=["https://graph.microsoft.com/.default"]
    )
    if "access_token" in result:
        return result["access_token"]
    else:
        raise Exception("Could not obtain access token")  # pylint: disable=broad-exception-raised


def collect_logs(device_id, client_id, client_secret, tenant_id):
    """Initiate a device log collection request via the Microsoft Graph API."""
    token = get_access_token(client_id, client_secret, tenant_id)
    headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}
    try:
        response = requests.post(
            f"https://graph.microsoft.com/beta/deviceManagement/managedDevices('{device_id}')/createDeviceLogCollectionRequest",
            json={"templateType": 0},
            headers=headers,
        )
        print(response.json())
        response.raise_for_status()
        return response.json()["value"]
    except requests.exceptions.RequestException as e:
        logger.error(f"Failed to collect logs: {e}")
        raise


def get_log_status(device_id, client_id, client_secret, tenant_id):
    """Check the status of the most recent log collection request."""
    token = get_access_token(client_id, client_secret, tenant_id)
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
        "consistencylevel": "eventual",
    }
    try:
        response = requests.get(
            f"https://graph.microsoft.com/beta/deviceManagement/managedDevices('{device_id}')/logCollectionRequests?$select=id,status,managedDeviceId,errorCode,requestedDateTimeUTC,receivedDateTimeUTC,initiatedByUserPrincipalName&",
            headers=headers,
        )
        response.raise_for_status()
        logs = response.json()["value"]
        logs.sort(key=lambda x: x["requestedDateTimeUTC"])
        return logs[-1]
    except requests.exceptions.RequestException as e:
        logger.error(f"Failed to get log status: {e}")
        raise


def download_logs(device_id, log_id, client_id, client_secret, tenant_id):
    """Get a download URL for the collected logs."""
    token = get_access_token(client_id, client_secret, tenant_id)
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    }
    try:
        response = requests.post(
            f"https://graph.microsoft.com/beta/deviceManagement/managedDevices('{device_id}')/logCollectionRequests('{log_id}')/createDownloadUrl",
            headers=headers,
            json={},
        )
        response.raise_for_status()
        return response.json()["value"]
    except requests.exceptions.RequestException as e:
        logger.error(f"Failed to download logs: {e}")
        raise


def summarize_logs(file_path):
    """Summarize the Intune Management Extension logs using Azure OpenAI."""
    try:
        with open(file_path, "r") as file:
            log_content = file.read()
    except FileNotFoundError:
        logger.error(f"Log file not found: {file_path}")
        raise
    except PermissionError:
        logger.error(f"Permission denied reading: {file_path}")
        raise

    # Truncate at a newline boundary so we don't cut a log line in half
    if len(log_content) > MAX_LOG_CHARS:
        truncated = log_content[-MAX_LOG_CHARS:]
        first_newline = truncated.find("\n")
        if first_newline != -1:
            truncated = truncated[first_newline + 1:]
        log_content = truncated

    prompt = f"""
    You are an senior intune engineer. Your task is to find errors in the [Intune Management Extension log]. Give the user a summary of the log an point him to potential errors on an structured way. Explain to the user what is mean and how he can check and troubleshoot this.

    [Intune Management Extension log]
    {log_content}
    [END Intune Management Extension log]
    """

    try:
        client = AzureOpenAI(
            azure_endpoint=OPEN_AI_ENDPOINT,
            api_key=OPEN_AI_API_KEY,
            api_version="2024-02-01",
        )

        completion = client.chat.completions.create(
            model="gpt-4o",
            temperature=0,
            messages=[
                {
                    "role": "user",
                    "content": prompt,
                }
            ],
        )

        print(completion.choices[0].message.content)
    except Exception as e:
        logger.error(f"Error calling Azure OpenAI: {e}")
        raise


def main():
    """Main function: check log status, download, extract, and summarize."""
    _check_required_env_vars()

    logger.info("Starting IME Summarizer")
    try:
        log_status = get_log_status(DEVICE_ID, CLIENT_ID, CLIENT_SECRET, TENANT_ID)
        logger.info(log_status)
        if log_status["status"] != "completed":
            logger.error("Log collection is not completed yet")
            return
        log_id = log_status["id"].replace(f"{DEVICE_ID}_", "")
        log_download_url = download_logs(
            DEVICE_ID, log_id, CLIENT_ID, CLIENT_SECRET, TENANT_ID
        ).replace('"', "")

        logger.info(log_download_url)

        urllib.request.urlretrieve(log_download_url, "logs.zip")

        with zipfile.ZipFile("logs.zip", "r") as zip_ref:
            zip_ref.extractall("logs")

        # Find the IME logs folder
        log_folder = None
        for folder in os.listdir("logs"):
            if "ProgramData_Microsoft_IntuneManagementExtension_Logs" in folder:
                log_folder = folder
                break

        if log_folder is None:
            logger.error("Could not find IME logs folder in extracted archive")
            return

        logger.info(log_folder)
        summarize_logs(f"logs/{log_folder}/intunemanagementextension.log")

    except Exception as e:
        logger.error(f"Fatal error in main: {e}")
        sys.exit(1)


# def main():
#     """Start log collection"""
#     log = collect_logs(DEVICE_ID, CLIENT_ID, CLIENT_SECRET, TENANT_ID)
#     logger.info(log)


if __name__ == "__main__":
    main()
