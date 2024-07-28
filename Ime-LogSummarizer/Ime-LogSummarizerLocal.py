import os
from openai import AzureOpenAI

file_path = os.path.join(
    "C:\\",
    "ProgramData",
    "Microsoft",
    "IntuneManagementExtension",
    "Logs",
    "IntuneManagementExtension.log",
)
with open(file_path, "r") as file:
    log_content = file.read()

log_content = log_content[-128000:]

prompt = f"""
You are an senior intune engineer. Your task is to find errors in the [Intune Management Extension log]. Give the user a summary of the log an point him to potential errors on an structured way. Explain to the user what is mean and how he can check and troubleshoot this.

[Intune Management Extension log]
{log_content}
[END Intune Management Extension log]
"""

client = AzureOpenAI(
    azure_endpoint="https://YOUR_ENDPOINT.openai.azure.com/",
    api_key="YOUR_APIKEY",
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
