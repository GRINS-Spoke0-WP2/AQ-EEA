# 3. Change temporal resolution ####

#This script convert hourly measurements into daily data

library(doParallel)
registerDoParallel(cores=detectCores()/3)
library(foreach)
library(dplyr)
library(imputeTS)
library(lubridate)

rm(list = ls())
gc()
try(setwd("/opt/wp02/FRK-GRINS/AQ-EEA"))
source("v.1.0.2/script/functions_v102.R")
EEA_files <-
  list.files("v.1.0.0/data/preprocessing/1p_1y_subsetted", pattern = ".Rdata")
EEA_short <- lapply(EEA_files, function(x) {
  nc <- nchar(x)
  substr(x, 1, nc - 6)
})
EEA_short <- unlist(EEA_short)
pol <-
  unique(sapply(EEA_short, function(x)
    substring(x, 1, nchar(x) - 5)))
# p <- pol[1] p <- pol[4] p <- pol[6] p <- pol[7]
for (p in pol) {
  print(paste("starting", p))
  EEA_pol <- EEA_files[grepl(paste0(p, "_"), EEA_files)]
  df_EEA <- foreach (EEA_y = EEA_pol, .combine = rbind) %dopar% {
    load(paste0("v.1.0.0/data/preprocessing/1p_1y_subsetted/", EEA_y))
    print(paste("merged done for", p))
    df_EEA
  }
  stazz <- unique(df_EEA$AirQualityStation)
  foreach (s = stazz, # s = stazz[1] s = stazz[134] s="STA.IT2151A"
           .packages = c("lubridate", "imputeTS")) %dopar% {
             print(paste(round((
               which(stazz == s) / length(stazz)
             ) * 100, 2), "%"))
             sub <- subset(df_EEA, AirQualityStation == s)
             sub <- sub[order(sub$DatetimeBegin),]
             sub <- sub[!duplicated(sub$DatetimeBegin),]
             y <- substr(sub$DatetimeBegin, 1, 4)
             y <- unique(y)
             if(s == "STA.IT1243A" & p == pol[6]){
               sub <- sub[!sub$ID_AVGTIME==2,]
             }
             if (!all(sub$ID_AVGTIME %in% c(1, 2, 3))) {
               print(paste(s, "of", p))
               stop("unknown temporal resolution")
             }
             else if (length(unique(sub$ID_AVGTIME)) != 1 &&
                      3 %in% unique(sub$ID_AVGTIME)) {
               print(paste("station", s, "of", p, "is mixed"))
               diviso <- mixed(sub, s)
               diviso_1_list <- daily(diviso[[1]], s)
               if (nrow(diviso[[2]]) > 24) {
                 diviso_2_list <- hourly(diviso[[2]], s)
               } else{
                 diviso_2_list <- list(diviso_2_1 = diviso[[2]][-c(1:nrow(diviso[[2]])), ],
                                       diviso_2_2 = diviso_1_list[[2]][-c(1:nrow(diviso_1_list[[2]]))])
               }
               EEA_daily <- rbind(diviso_1_list[[1]], diviso_2_list[[1]])
               EEA_daily_uncertainty <- rbind(diviso_1_list[[2]], diviso_2_list[[2]])
             }
             else if (length(unique(sub$ID_AVGTIME)) == 1 &&
                      unique(sub$ID_AVGTIME) == 3) {
               print(paste("station", s, "of", p, "is all daily"))
               EEA_daily_list <- daily(sub, s)
               EEA_daily <- EEA_daily_list[[1]]
               EEA_daily_uncertainty <- EEA_daily_list[[2]]
             }
             else if (all(unique(sub$ID_AVGTIME) %in% c(1, 2))) {
               print(paste("station", s, "of", p, "is all hourly/bi-hourly"))
               EEA_daily_list <- hourly(sub, s) #EEA_daily_list <- daily_list
               EEA_daily <- EEA_daily_list[[1]]
               EEA_daily_uncertainty <- EEA_daily_list[[2]]
             }
             else {
               stop(paste(s, "in", p, "non ricade in nessun ambito"))
             }
             save(EEA_daily,
                  file = paste0("v.1.0.2/data/daily/1p_1s/", p, "_", s, ".Rdata"))
             save(EEA_daily_uncertainty,
                  file = paste0("v.1.0.2/data/daily/1p_1s/", p, "_", s, "_uncertainty.Rdata"))
             rm(EEA_daily)
           }
}
