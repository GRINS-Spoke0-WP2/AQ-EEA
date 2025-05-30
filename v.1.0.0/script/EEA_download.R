# 1. EEA download ####
setwd("AQ-EEA/v.1.0.0")
library(doParallel)
library(foreach)
library(httr)
registerDoParallel(cores=detectCores())

base_url <- "https://fme.discomap.eea.europa.eu/fmedatastreaming/AirQualityDownload/AQData_Extract.fmw"

# Define parameters
foreach (i = c(1,5,7,8,10,35,38,6001),
         .packages = c("httr")) %dopar% { 
  parameters <- list(
    CountryCode = "IT",
    CityName = "",
    Pollutant = i,
    Year_from = 2013,
    Year_to = 2023,
    Source = "All", 
    Output = "TEXT",
    TimeCoverage = "Year",
    token = "8f3a54b3e7054080813237004b35694fbff43580" #it may change?
  )
  
  # Construct the full URL
  url <- paste(base_url, "?", paste0(names(parameters), "=", unlist(parameters), collapse = "&"), sep = "")

  response <- GET(url)
  content_text <- content(response, "text", encoding = "UTF-8")
  download_links <- unlist(strsplit(content_text,"\r\n"))
  download_links <- sub("^[\uFEFF]", "", download_links)
  if (length(download_links)!=0) {
    for (j in 1:length(download_links)) {
      download.file(download_links[j],
                    paste0("data/raw/",
                           basename(download_links[j])))
    } 
  }
}
