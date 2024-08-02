library(doParallel)
registerDoParallel()
library(foreach)

rm(list = ls())
gc()

daily_files <- list.files("data/AQ/EEA/daily/1p_1s", pattern = ".Rdata")
load(paste0("data/AQ/EEA/daily/1p_1s/", daily_files[1]))
AirQualityStation <- unique(EEA_daily$AirQualityStation)
for (d in daily_files[-1]) {
  load(paste0("data/AQ/EEA/daily/1p_1s/", d))
  AirQualityStation <- unique(c(AirQualityStation,
                                unique(EEA_daily$AirQualityStation)))
}
load("data/AQ/EEA/metadataEEA.Rdata")
EEA_meta <- merge(data.frame(AirQualityStation = AirQualityStation),
                  unique(metadataEEA[, c(2, 7, 8, 9, 11, 12)]),
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
      load(paste0("data/AQ/EEA/daily/1p_1s/", i))
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
EEA_data <- EEA_all_daily
save(EEA_data,file="data/AQ/EEA/daily/EEA_dataset.Rdata")
