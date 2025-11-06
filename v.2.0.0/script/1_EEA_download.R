library(httr)
library(jsonlite)
library(lubridate) # Per la gestione delle date

# Accesso a NEXUS ## non MinIO!
# user: unibg 
# password: $2MYzlm8#!Hk2Z
# https://131.175.206.80:5443

# # setwd("AQ-EEA/v.2.0.0")
length_window <- 2 # pick even number
date_sel <- as.Date("2024-01-02")
date_start <- date_sel - (length_window/2)
date_end <- date_sel + (length_window/2)
# in AQ_CLEM_AMELIA.R
# download ####

library(httr2)
library(glue)

# Parametri di base
api_url <- "https://eeadmz1-downloads-api-appservice.azurewebsites.net/ParquetFile/async"
download_path <- "/data/raw" #cambiare
file_name <- "daily_EEA_R.zip"

# Corpo della richiesta
request_body <- list(
  countries = list("IT"),
  cities = list(),
  pollutants = list("NO2"),
  dataset = 2, #1 real-time, #2 E1a verified, #3 historical
  dateTimeStart = paste0(date_start,"T00:00:00Z"),
  dateTimeEnd = paste0(date_end,"T23:59:59Z"),
  aggregationType = "hour",
  email = "alessandro.fustamoro@unibg.it"
)

# Invia la richiesta asincrona
resp <- request(api_url) |>
  req_body_json(request_body) |>
  req_perform()

if (resp_status(resp) != 200) {
  stop(glue("Errore: richiesta fallita con status {resp_status(resp)}"))
}

download_url <- resp_body_string(resp)
cat("Link per il file:", download_url, "\n")

# Polling per scaricare il file quando pronto
wait_for_file <- function(url, timeout = 2*3600, sleep = 20) {
  start <- Sys.time()
  repeat {
    if (as.numeric(difftime(Sys.time(), start, units = "secs")) > timeout) {
      stop("Timeout: file non disponibile dopo 2 ore.")
    }
    r <- try(request(url) |> req_perform(), silent = T)
    if (inherits(r, "try-error") || resp_status(r) == 404) {
      print("file not ready, retrying in 20 seconds...")
      Sys.sleep(sleep)
    } else {
      return(r)
    }
  }
}

cat("Attendo che il file sia pronto...\n")
final_resp <- wait_for_file(download_url)

# Salva il file ZIP
dir.create(download_path, recursive = TRUE, showWarnings = FALSE)
writeBin(resp_body_raw(final_resp), file.path(download_path, file_name))
cat(glue("File salvato in: {file.path(download_path, file_name)}\n"))
folder <- "/data/raw"
filename <- "daily_EEA_R.zip"
f_t <- file.exists(file.path(folder, filename))
if(f_t == T){cat("Il file esiste nella cartella")}else{cat("Il file NON esiste nella cartella")}
# extract_path <- file.path(download_path, "unzip")
# dir.create(extract_path, recursive = TRUE, showWarnings = FALSE)
# unzip(file.path(download_path, file_name),exdir = extract_path)
# 
# # from parquet to csv
# library(arrow)
# elements_from_zip <- list.files("data/raw/unzip")
# if(length(elements_from_zip) ==1){
#   extract_path <- paste0(extract_path,"/",elements_from_zip)
#   }
# EEA_files <- list.files(extract_path,pattern = ".parquet")
# # new_stations <- paste0("STA.",substr(EEA_files,5,11))
# # setdiff(new_stations,unique(GRINS_AQCLIM_points_Italy$AirQualityStation))
# # setdiff(unique(GRINS_AQCLIM_points_Italy$AirQualityStation),new_stations)
# # i <- EEA_files[1]
# for (i in EEA_files) {
#   df <- read_parquet(paste0(extract_path,"/",i))
#   df$AirQualityStation <- paste0("STA.",substr(i,5,11))
#   write.csv(df,file = paste0(extract_path,"/",substr(i,1,nchar(i)-8),".csv"),
#             row.names = F)
# }
# 

# source("AQ-EEA/v.2.0.0/script/exportMinIO.R") DA MODIFICARE!



