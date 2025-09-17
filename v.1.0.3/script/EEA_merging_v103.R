# EEA_merging ####

library(doParallel)
registerDoParallel()
library(foreach)

rm(list = ls())
gc()
try(setwd("AQ-EEA"))

daily_files <- list.files("v.1.0.2/data/daily/1p_1s", pattern = ".Rdata")
uncertainty_files <- daily_files[grep("uncertainty",daily_files)] #TO DO!
daily_files <- setdiff(daily_files,uncertainty_files)
load(paste0("v.1.0.2/data/daily/1p_1s/", daily_files[1]))
AirQualityStation <- unique(EEA_daily$AirQualityStation)
for (d in daily_files[-1]) {
  load(paste0("v.1.0.2/data/daily/1p_1s/", d))
  AirQualityStation <- unique(c(AirQualityStation,
                                unique(EEA_daily$AirQualityStation)))
}
# source("v.1.0.0/script/EEA_metadata.R")
load("v.1.0.0/data/metadataEEA.Rdata")
EEA_meta <- merge(data.frame(AirQualityStation = AirQualityStation),
                  metadataEEA,
                  all.x = T)
EEA_meta <- EEA_meta[!duplicated(EEA_meta$AirQualityStation),] #remove duplicated values

time <-
  seq.Date(as.Date("2013/1/1"), as.Date("2023/12/31"), by = "days")

EEA_meta <- cbind(EEA_meta[rep(1:nrow(EEA_meta),length(time)),],rep(time,each=length(AirQualityStation)))
names(EEA_meta)[7]<-"time"

EEA_pol <- lapply(daily_files, function(x) {
  nc <- nchar(x)
  substr(x, 1, nc - 18)
})
EEA_pol <- unique(unlist(EEA_pol))

for (p in EEA_pol) {
  daily_files_p <- daily_files[grep(paste0(p, "_"), daily_files)]
  EEA_daily <-
    foreach (i = daily_files_p, .combine = rbind) %dopar% {
      load(paste0("v.1.0.2/data/daily/1p_1s/", i))
      EEA_daily
    }
  # save(EEA_daily,file=paste0("data/AQ/EEA/daily/T/",p,".Rdata"))
  if (p == EEA_pol[1]) {
    EEA_all_daily <- merge(EEA_meta,EEA_daily,all.x=T)
  } else{
    EEA_all_daily <- merge(EEA_all_daily, EEA_daily, all.x = T)
  }
  print(paste(p, "completed"))
}

for (p in EEA_pol) { #p <- EEA_pol[1]
  uncertainty_files_p <- uncertainty_files[grep(paste0(p, "_"), uncertainty_files)]
  EEA_daily_uncertainty <-
    foreach (i = uncertainty_files_p, .combine = rbind) %dopar% {
      load(paste0("v.1.0.2/data/daily/1p_1s/", i))
      EEA_daily_uncertainty
    }
  # save(EEA_daily,file=paste0("data/AQ/EEA/daily/T/",p,".Rdata"))
  if (p == EEA_pol[1]) {
    EEA_all_daily_uncertainty <- merge(EEA_meta,EEA_daily_uncertainty,all.x=T)
  } else{
    EEA_all_daily_uncertainty <- merge(EEA_all_daily_uncertainty, EEA_daily_uncertainty, all.x = T)
  }
  print(paste(p, "completed"))
}

AQ_EEA_v100_df <- EEA_all_daily
AQ_EEA_sd_v100_df <- EEA_all_daily_uncertainty
# save(AQ_EEA_v100_df,file="v.1.0.3/data/daily/AQ_EEA_v100_df.rda")

# EEA_fix100_do_101 ####
#this script eliminates negative values setting it to NAs
# load("v.1.0.3/data/daily/AQ_EEA_v100_df.rda")

meta_aq <- unique(AQ_EEA_v100_df[,c(1,3:7)])
# STA.IT0775A 9.385000 46.13722 228.0 background suburban <<-- eliminated
# STA.IT0776A 9.395833 45.84944 214.0 traffic urban
AQ_EEA_v100_df <- AQ_EEA_v100_df[!AQ_EEA_v100_df$AirQualityStation=="STA.IT0775A",]
AQ_EEA_sd_v100_df <- AQ_EEA_sd_v100_df[!AQ_EEA_sd_v100_df$AirQualityStation=="STA.IT0775A",]

# 9.39995 45.86375 from 
AQ_EEA_v100_df[AQ_EEA_v100_df$AirQualityStation=="STA.IT1826A",3:4]<-
  matrix(rep(c(9.39995,45.86375),each=length(unique(AQ_EEA_v100_df$time)),byrow=T),ncol=2)
AQ_EEA_sd_v100_df[AQ_EEA_sd_v100_df$AirQualityStation=="STA.IT1826A",3:4]<-
  matrix(rep(c(9.39995,45.86375),each=length(unique(AQ_EEA_sd_v100_df$time)),byrow=T),ncol=2)

AQ_EEA_v100_df <- AQ_EEA_v100_df[!AQ_EEA_v100_df$AirQualityStation=="STA.IT2300A",]
AQ_EEA_sd_v100_df <- AQ_EEA_sd_v100_df[!AQ_EEA_sd_v100_df$AirQualityStation=="STA.IT2300A",]

length(unique(AQ_EEA_v100_df$AirQualityStation))
length(unique(AQ_EEA_sd_v100_df$AirQualityStation))
nrow(unique(AQ_EEA_v100_df[,3:4])) #OK
nrow(unique(AQ_EEA_sd_v100_df[,3:4])) #OK
#finish

AQ_EEA_v101_df <- AQ_EEA_v100_df
AQ_EEA_sd_v101_df <- AQ_EEA_sd_v100_df
save(AQ_EEA_v101_df,file = "v.1.0.3/data/daily/AQ_EEA_v101_df.rda")
save(AQ_EEA_sd_v101_df,file = "v.1.0.3/data/daily/AQ_EEA_sd_v101_df.rda")

which.max(AQ_EEA_sd_v101_df$sd_mean_PM2.5)
AQ_EEA_sd_v101_df[2418198,]
# STA.IT2151A 2023-11-25
#CHECK##
load("v.1.0.0/data/preprocessing/1p_1y_subsetted/PM2.5_2023.Rdata")
sub <- subset(df_EEA,AirQualityStation=="STA.IT2151A")
library(lubridate)
sub2 <- subset(sub,as_date(DatetimeBegin)==as.Date("2023-11-25"))
# all_day <- seq.POSIXt(from = as.POSIXct("2023-11-25 00:00:00",tz = "Etc/GMT-1"),
#            to = as.POSIXct("2023-11-25 23:00:00",tz = "Etc/GMT-1"), 
#            by="hour")
# ext_df <- merge(data.frame(DatetimeBegin=all_day),sub2,all=T)
# mod <- StructTS(ext_df$Concentration[-c(1:6)],fixed = c(516.7,NA),type = "level") #from functions on all ts
# KalmanSmooth(ext_df$Concentration,mod$model)
#OK !!!
# CHECK END#

length(unique(AQ_EEA_v101_df$time))
length(unique(AQ_EEA_v101_df$AirQualityStation))

if (length(unique(AQ_EEA_v101_df$time))*length(unique(AQ_EEA_v101_df$AirQualityStation))!=nrow(AQ_EEA_v101_df)){
  print("houston we have a problem!")
}


# exporting station registry####
names(AQ_EEA_v101_df)
meta_aq <- unique(AQ_EEA_v101_df[,c(1,3:7)])
Station_registry_information <- meta_aq
save(Station_registry_information,file = "v.1.0.3/data/Zenodo/Station_registry_information.rda")
write.table(
  cbind(
    Station_registry_information[, 1],
    format(Station_registry_information[, c(3:4)], digits = 9, scientific =
             F),
    Station_registry_information[, 4:6]),
  file = "v.1.0.3/data/Zenodo/Station_registry_information.CSV",
  row.names = F,
  col.names = names(Station_registry_information),
  quote = F,
  sep = ",",
  dec = "."
)

# EEA_merging with ERA5 ####
rm(list=ls())
gc()
library(sp)
library(spacetime)
load("v.1.0.3/data/daily/AQ_EEA_v101_df.rda")
load("v.1.0.1/data/WE_C3S_v100_ST_ERA5SL.rda")
load("v.1.0.1/data/WE_C3S_v100_ST_ERA5Land.rda")
AQ_EEA_v101_df<-AQ_EEA_v101_df[order(AQ_EEA_v101_df$time,AQ_EEA_v101_df$Latitude,AQ_EEA_v101_df$Longitude),]
aq_eea_sp <- unique(AQ_EEA_v101_df[,c(3:4)])
coordinates(aq_eea_sp)<-c("Longitude","Latitude")
AQ_EEA <- STFDF(data=AQ_EEA_v101_df,
                sp=aq_eea_sp,
                time=unique(AQ_EEA_v101_df$time))
EEA_5SL <- cbind(AQ_EEA@data,over(AQ_EEA,WE_C3S_v100_ST_ERA5SL)[,-c(1:3)])
EEA_Land <- cbind(AQ_EEA@data,over(AQ_EEA,WE_C3S_v100_ST_ERA5Land)[,-c(1:3)])
na_era5land <- is.na(EEA_Land$lai_hv)
EEA_CL <- EEA_Land
EEA_CL[na_era5land,56:63] <- EEA_5SL[na_era5land,57:64]
na_era5land <- is.na(EEA_Land$ssr)
EEA_CL[na_era5land,56:63] <- EEA_5SL[na_era5land,57:64]

EEA_CL <- cbind(EEA_CL,EEA_5SL[,56])
names(EEA_CL)[64]<-"blh"
summary(EEA_CL)
# s <- sample(unique(EEA_CL$AirQualityStation),1)
# plot(EEA_CL$t2m[EEA_CL$AirQualityStation==s],type="l")
names(EEA_CL)[8:55]<-paste0("AQ_",names(EEA_CL)[8:55])
names(EEA_CL)[56:64]<-paste0("CL_",names(EEA_CL)[56:64])
GRINS_AQCLIM_points_Italy <- EEA_CL[,-c(3,4,5,6,7)]

save(GRINS_AQCLIM_points_Italy, file = "v.1.0.3/data/Zenodo/GRINS_AQCLIM_points_Italy.rda")

# Exporting CSV ####
load("v.1.0.3/data/GRINS_AQCLIM_points_Italy.rda")
GRINS_AQCLIM_points_Italy$CL_winddir<-as.factor(GRINS_AQCLIM_points_Italy$CL_winddir)
for (y in c(2013,2015,2017,2019,2021,2023)) {
  d <- as.Date(paste0(y,"-01-01"))
  d_end <- as.Date(paste0(y+1,"-12-31"))
  sub <- subset(GRINS_AQCLIM_points_Italy,GRINS_AQCLIM_points_Italy$time > d & GRINS_AQCLIM_points_Italy$time < d_end)
  write.table(
    sub,
    file = paste0("v.1.0.3/data/Zenodo/GRINS_AQCLIM_points_Italy_y",y,y+1,".csv"), #adjust 2023
    row.names = F,
    col.names = names(sub),
    quote = F,
    sep = ",",
    dec = "."
  )
}
# #one file
# write.table(
#   cbind(
#     GRINS_AQCLIM_points_Italy[, 1:2],
#     format(GRINS_AQCLIM_points_Italy[, c(3:4)], digits = 9, scientific =
#              F),
#     GRINS_AQCLIM_points_Italy[, 5:7],
#     format(GRINS_AQCLIM_points_Italy[, c(8:64)], digits = 4, scientific =
#              T)
#   ),
#   file = "AQ-EEA/v.1.0.1/data/GRINS_AQCLIM_points_Italy.csv",
#   row.names = F,
#   col.names = names(GRINS_AQCLIM_points_Italy),
#   quote = F,
#   sep = ",",
#   dec = "."
# )
# 
# 

# exportin uncertainty ####
rm(list=ls())
gc()
load("v.1.0.3/data/daily/AQ_EEA_sd_v101_df.rda")
unc <- AQ_EEA_sd_v101_df
rm(AQ_EEA_sd_v101_df)
names(unc)
unc <- unc[,-c(3:7)]

unc2 <- unc[!apply(unc[,-c(1,2)], 1, function(x) all(is.na(x) | x==0)),]

summary(unc)
summary(unc2)

GRINS_AQCLIM_imputation_uncertainty <- unc2

write.table(
  GRINS_AQCLIM_imputation_uncertainty,
  file = paste0("v.1.0.3/data/Zenodo/GRINS_AQCLIM_imputation_uncertainty.csv"), #adjust 2023
  row.names = F,
  col.names = names(GRINS_AQCLIM_imputation_uncertainty),
  quote = F,
  sep = ",",
  dec = "."
)

save(GRINS_AQCLIM_imputation_uncertainty, file = "v.1.0.3/data/Zenodo/GRINS_AQCLIM_imputation_uncertainty.rda")

