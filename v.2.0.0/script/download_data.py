# -*- coding: utf-8 -*-
"""
Spyder Editor

This is a temporary script file.
"""

# %%

import os
# os.setcwd('v.2.0.0')

# %%

from datetime import datetime
import time
import requests
import zipfile
    
# %% async endpoint 
# ok questo funziona 

apiUrl = "https://eeadmz1-downloads-api-appservice.azurewebsites.net/"
endpoint = "ParquetFile/async"
downloadPath = "v.2.0.0/data/raw/"
fileName = "daily_EEA.zip"
request_body = {
"countries": ["IT"],
"cities": [],
"pollutants": ["NO2"],
"dataset": 2,
"dateTimeStart": "2024-01-01T00:00:00Z",
"dateTimeEnd": "2024-01-01T23:59:59Z",
"aggregationType": "hour",
"email": "alessandro.fustamoro@unibg.it"
}
response = requests.post(apiUrl + endpoint, json=request_body)

print("Status:", response.status_code)
print("Headers:", response.headers)
print("Text:", response.text[:500])  # first 500 chars

downloadFile = response.text
print(downloadFile)


t_start = datetime.now()
while True:
    if (datetime.now()-t_start).total_seconds() > 3600: # stop after 1 hour if the file has not been created
        break
    parquetResponse = requests.get(downloadFile)
    if parquetResponse.status_code==404:
        time.sleep(20)
    else:
        break
with open(downloadPath + fileName, "wb") as fp:
    fp.write(parquetResponse.content)
                     
# %%

import pandas as pd
df = pd.read_parquet('v.2.0.0/data/raw/E1a/a.parquet', engine='pyarrow')

fileName = "daily_EEA.zip"
with zipfile.ZipFile(downloadPath + fileName, 'r') as zip_ref:
    zip_ref.extractall(downloadPath + fileName)

# %%

# # %% simple
# # non funziona se non specifichi la città

# apiUrl = "https://eeadmz1-downloads-api-appservice.azurewebsites.net/"
# endpoint = "ParquetFile"
# downloadPath = "v.2.0.0/data/raw/"
# fileName = "daily_EEA.zip"
# # Request body
# request_body = {
# "countries": ["IT"],
# "cities": [],
# "pollutants": ["NO2"],
# "dataset": 2,
# "dateTimeStart": "2024-01-01T00:00:00.000Z",
# "dateTimeEnd": "2024-01-10T00:00:00.000Z",
# "aggregationType": "hour",
# "email": "alessandro.fustamoro@unibg.it"
# }

# response = requests.post(apiUrl + endpoint, json=request_body)

# print("Status:", response.status_code)
# print("Headers:", response.headers)
# print("Text:", response.text[:500])  # first 500 chars

# # A get request to the API
# downloadFile = requests.post(apiUrl+endpoint, json=request_body).content
# # Store in local path
# output = open(downloadPath+fileName, 'wb')
# output.write(downloadFile)

# # %% list of URLs funziona ma tanti files e poi diversi tra dataset 1 e 2
#     # poi 1000 file se metto un giorno da verificare se i file sono sempre uguali se cambio il periodo?
#     # diceva che non dipendenva dal periodo
    
# apiUrl = "https://eeadmz1-downloads-api-appservice.azurewebsites.net/"
# endpoint = "ParquetFile/urls"
# downloadFolder = "v.2.0.0/data/raw"
# request_body = {
# "countries": ["IT"],
# "cities": [],
# "pollutants": ["NO2", "NOX as NO2", "PM10"],
# "dataset": 2,
# "dateTimeStart": "2024-01-01T00:00:00Z",
# "dateTimeEnd": "2024-01-01T23:59:59Z",
# "aggregationType": "hour",
# "email": "alessandro.fustamoro@unibg.it"
# }
# response = requests.post(f"{apiUrl}{endpoint}", json=request_body)
# urls = response.text.split("\n")[1:]
# urls_1 = urls # dataset 1
# urls_2 = urls # dataset 2
# urls_2minus1 = set(urls_2) - set(urls_1) # what?!?!
# urls_1minus2 = set(urls_1) - set(urls_2)

# os.makedirs(downloadFolder, exist_ok=True)
# for url in urls[0]:
#     fileName = url.split("/")[-1]
#     with open(f"{downloadFolder}/{fileName}", "wb") as fp:
#                   fp.write(requests.get(url).content)
 
# # %%

# %%