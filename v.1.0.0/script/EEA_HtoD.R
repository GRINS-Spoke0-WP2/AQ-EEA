# 3. Change temporal resolution ####

#This script convert hourly measurements into daily data

library(doParallel)
registerDoParallel(cores=5)
library(foreach)
library(dplyr)
library(imputeTS)
library(lubridate)

rm(list = ls())
gc()
setwd("AQ-EEA/v.1.0.0")
source("script/functions.R")
EEA_files <-
  list.files("data/preprocessing/1p_1y_subsetted", pattern = ".Rdata")
EEA_short <- lapply(EEA_files, function(x) {
  nc <- nchar(x)
  substr(x, 1, nc - 6)
})
EEA_short <- unlist(EEA_short)
pol <-
  unique(sapply(EEA_short, function(x)
    substring(x, 1, nchar(x) - 5)))

for (p in pol[3:4]) {
  print(paste("starting", p))
  EEA_pol <- EEA_files[grepl(paste0(p, "_"), EEA_files)]
  df_EEA <- foreach (EEA_y = EEA_pol, .combine = rbind) %dopar% {
    load(paste0("data/preprocessing/1p_1y_subsetted/", EEA_y))
    print(paste("merged done for", p))
    df_EEA
  }
  stazz <- unique(df_EEA$AirQualityStation)
  foreach (s = stazz,
           .packages = c("lubridate", "imputeTS")) %do% {
             print(paste(round((
               which(stazz == s) / length(stazz)
             ) * 100, 2), "%"))
             sub <- subset(df_EEA, AirQualityStation == s)
             sub <- sub[order(sub$DatetimeBegin),]
             y <- substr(sub$DatetimeBegin, 1, 4)
             y <- unique(y)
             if (!all(sub$ID_AVGTIME %in% c(1, 2, 3))) {
               print(paste(s, "of", p))
               stop("unknown temporal resolution")
             }
             else if (length(unique(sub$ID_AVGTIME)) != 1 &&
                      3 %in% unique(sub$ID_AVGTIME)) {
               print(paste("station", s, "of", p, "is mixed"))
               diviso <- mixed(sub, s)
               diviso_1 <- daily(diviso[[1]], s)
               if (nrow(diviso[[2]]) > 2) {
                 diviso_2 <- hourly(diviso[[2]], s)
               } else{
                 diviso_2 <- diviso[[2]][-c(1:nrow(diviso[[2]])), ]
               }
               EEA_daily <- rbind(diviso_1, diviso_2)
             }
             else if (length(unique(sub$ID_AVGTIME)) == 1 &&
                      unique(sub$ID_AVGTIME) == 3) {
               print(paste("station", s, "of", p, "is all daily"))
               EEA_daily <- daily(sub, s)
             }
             else if (all(unique(sub$ID_AVGTIME) %in% c(1, 2))) {
               print(paste("station", s, "of", p, "is all hourly/bi-hourly"))
               EEA_daily <- hourly(sub, s)
             }
             else {
               stop(paste(s, "in", p, "non ricade in nessun ambito"))
             }
             save(EEA_daily,
                  file = paste0("data/daily/1p_1s/", p, "_", s, ".Rdata"))
             rm(EEA_daily)
           }
}
