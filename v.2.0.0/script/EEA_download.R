library(httr)
library(jsonlite)
library(lubridate) # Per la gestione delle date

setwd("AQ-EEA/v.2.0.0")

api_url <- "https://eeadmz1-downloads-api-appservice.azurewebsites.net/"
endpoint <- "ParquetFile/async"
download_folder <- "data/raw"
fileName <- "EEA_raw_data.zip"

request_body <- list(
  countries = list("IT"),
  cities = list(),
  pollutants = list("NO2", "NOX as NO2", "PM10"),
  dataset = 2,
  dateTimeStart = "2024-02-01T00:00:00Z",
  dateTimeEnd = "2024-02-03T23:59:59Z",
  aggregationType = "hour",
  email = "alessandro.fustamoro@unibg.it"
)

response <- POST(
  url = paste0(api_url, endpoint),
  body = toJSON(request_body, auto_unbox = TRUE),
  encode = "json",
  add_headers("Content-Type" = "application/json")
)

downloadFile <- content(response, "text")
print(downloadFile)

# Percorso dove salvare il file
zip_path <- file.path(download_folder, fileName)

# Scaricare il file ZIP
status_code(response) == 200
download.file(downloadFile, zip_path, mode = "wb")

message("Download completato: ", zip_path)

