"""
Ime-LogSummarizerLocal: Read the local Intune Management Extension log file
and summarize errors/issues using Azure OpenAI (GPT-4o).

Requires environment variables:
  AZURE_OPENAI_API_KEY  - Azure OpenAI API key
  AZURE_OPENAI_ENDPOINT - Azure OpenAI endpoint URL (e.g. https://YOUR_NAME.openai.azure.com/)
"""

import os
import sys

from openai import AzureOpenAI

AZURE_OPENAI_API_KEY = os.environ.get("AZURE_OPENAI_API_KEY", "")
AZURE_OPENAI_ENDPOINT = os.environ.get("AZURE_OPENAI_ENDPOINT", "")

MAX_LOG_CHARS = 128000


def main():
    """Read local IME log and summarize it via Azure OpenAI."""
    if not AZURE_OPENAI_API_KEY:
        raise ValueError("AZURE_OPENAI_API_KEY environment variable is required")
    if not AZURE_OPENAI_ENDPOINT:
        raise ValueError("AZURE_OPENAI_ENDPOINT environment variable is required")

    file_path = os.path.join(
        "C:\\",
        "ProgramData",
        "Microsoft",
        "IntuneManagementExtension",
        "Logs",
        "IntuneManagementExtension.log",
    )

    try:
        with open(file_path, "r") as file:
            log_content = file.read()
    except FileNotFoundError:
        print(f"Error: Log file not found at {file_path}", file=sys.stderr)
        sys.exit(1)
    except PermissionError:
        print(f"Error: Permission denied reading {file_path}", file=sys.stderr)
        sys.exit(1)

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
            azure_endpoint=AZURE_OPENAI_ENDPOINT,
            api_key=AZURE_OPENAI_API_KEY,
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
        print(f"Error calling Azure OpenAI: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
