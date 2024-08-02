# 1. EEA download ####

library(doParallel)
library(foreach)
library(httr)
registerDoParallel(cores=detectCores())

#download data for January 2020
base_url <- "https://fme.discomap.eea.europa.eu/fmedatastreaming/AirQualityDownload/AQData_Extract.fmw"

# Define parameters
foreach (i = c(1,5,7,8,10,35,38,6001)) %dopar% { 
  parameters <- list(
    CountryCode = "IT",
    CityName = "",
    Pollutant = i,
    Year_from = 2013,
    Year_to = 2023,
    Source = "All", #"or E1a" or "E1b" (?)
    Output = "TEXT",
    TimeCoverage = "Year"
  )
  
  # Construct the full URL
  url <- paste(base_url, "?", paste0(names(parameters), "=", unlist(parameters), collapse = "&"), sep = "")

  response <- GET(url)
  content_text <- content(response, "text", encoding = "UTF-8")
  download_links <- unlist(strsplit(content_text,"\r\n"))
  download_links <- sub("^[\uFEFF]", "", download_links)
  # already_links <- substr(download_links,
  #                         nchar(download_links)-(28+nchar(as.character(i))),
  #                                                200) %in% list.files("GRINS/R_GRINS/data/EEA/raw")
  # download_links <- download_links[already_links==FALSE]
  if (length(download_links)!=0) {
    for (i in 1:length(download_links)) {
      download.file(download_links[i],
                    paste0("data/AQ/EEA/raw/",
                           basename(download_links[i])))
    } 
  }
}
