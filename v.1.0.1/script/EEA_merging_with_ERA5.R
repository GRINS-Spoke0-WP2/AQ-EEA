library(sp)
library(spacetime)
load("AQ-EEA/v.1.0.1/data/daily/AQ_EEA_v101_df.rda")
load("AQ-EEA/v.1.0.1/data/WE_C3S_v100_ST_ERA5SL.rda")
AQ_EEA_v101_df<-AQ_EEA_v101_df[order(AQ_EEA_v101_df$time,AQ_EEA_v101_df$Latitude,AQ_EEA_v101_df$Longitude),]
aq_eea_sp <- unique(AQ_EEA_v101_df[,c(3:4)])
coordinates(aq_eea_sp)<-c("Longitude","Latitude")
AQ_EEA <- STFDF(data=AQ_EEA_v101_df,
                sp=aq_eea_sp,
                time=unique(AQ_EEA_v101_df$time))
AQ.CLIM_v100 <- cbind(AQ_EEA@data,over(AQ_EEA,WE_C3S_v100_ST_ERA5SL)[,-c(1:3)])
names(AQ.CLIM_v100)[8:55]<-paste0("AQ_",names(AQ.CLIM_v100)[8:55])
names(AQ.CLIM_v100)[56:64]<-paste0("WE_",names(AQ.CLIM_v100)[56:64])

save(AQ.CLIM_v100, file = "AQ-EEA/v.1.0.1/data/AQ.CLIM_v100.rda")
AQ.CLIM_IT1323<-AQ.CLIM_v100
save(AQ.CLIM_IT1323, file = "AQ-EEA/v.1.0.1/data/AQ.CLIM_IT1323.rda")
