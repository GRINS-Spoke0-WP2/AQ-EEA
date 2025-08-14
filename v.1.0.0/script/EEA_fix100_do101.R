#this script eliminates negative values setting it to NAs

load("AQ-EEA/v.1.0.0/data/daily/AQ_EEA_v100_df.rda")

#negative values
sum(AQ_EEA_v100_df$min_SO2 < 0, na.rm = T)
sum(AQ_EEA_v100_df$q1_SO2 < 0, na.rm = T)
sum(AQ_EEA_v100_df$mean_SO2 < 0, na.rm = T)
sum(AQ_EEA_v100_df$med_SO2 < 0, na.rm = T)
sum(AQ_EEA_v100_df$q3_SO2 < 0, na.rm = T)

AQ_EEA_v100_df$min_SO2[AQ_EEA_v100_df$min_SO2 < 0] <- NA
AQ_EEA_v100_df$q1_SO2[AQ_EEA_v100_df$q1_SO2 < 0] <- NA
AQ_EEA_v100_df$mean_SO2[AQ_EEA_v100_df$mean_SO2 < 0] <- NA

sum(AQ_EEA_v100_df$min_O3 < 0, na.rm = T)
sum(AQ_EEA_v100_df$q1_O3 < 0, na.rm = T)
sum(AQ_EEA_v100_df$mean_O3 < 0, na.rm = T)
sum(AQ_EEA_v100_df$med_O3 < 0, na.rm = T)
sum(AQ_EEA_v100_df$q3_O3 < 0, na.rm = T)

AQ_EEA_v100_df$min_O3[AQ_EEA_v100_df$min_O3 < 0] <- NA
AQ_EEA_v100_df$q1_O3[AQ_EEA_v100_df$q1_O3 < 0] <- NA
AQ_EEA_v100_df$mean_O3[AQ_EEA_v100_df$mean_O3 < 0] <- NA
AQ_EEA_v100_df$med_O3[AQ_EEA_v100_df$med_O3 < 0] <- NA

#two station equal:
meta_aq <- unique(AQ_EEA_v100_df[,c(1,3:7)])

meta_aq[duplicated(meta_aq$Longitude),]
#manual
#
# STA.IT0775A 9.385000 46.13722 228.0 background suburban <<-- eliminated
# STA.IT0776A 9.395833 45.84944 214.0 traffic urban
summary(AQ_EEA_v100_df[AQ_EEA_v100_df$AirQualityStation=="STA.IT0775A",])
summary(AQ_EEA_v100_df[AQ_EEA_v100_df$AirQualityStation=="STA.IT0776A",])
summary(AQ_EEA_v100_df[AQ_EEA_v100_df$AirQualityStation=="STA.IT1826A",])

AQ_EEA_v100_df <- AQ_EEA_v100_df[!AQ_EEA_v100_df$AirQualityStation=="STA.IT0775A",]

# 9.39995 45.86375 from 
AQ_EEA_v100_df[AQ_EEA_v100_df$AirQualityStation=="STA.IT1826A",3:4]<-
  matrix(rep(c(9.39995,45.86375),each=length(unique(AQ_EEA_v100_df$time)),byrow=T),ncol=2)

#poi
summary(AQ_EEA_v100_df[AQ_EEA_v100_df$AirQualityStation=="STA.IT1251A",])
summary(AQ_EEA_v100_df[AQ_EEA_v100_df$AirQualityStation=="STA.IT2300A",])
AQ_EEA_v100_df <- AQ_EEA_v100_df[!AQ_EEA_v100_df$AirQualityStation=="STA.IT2300A",]

length(unique(AQ_EEA_v100_df$AirQualityStation))
nrow(unique(AQ_EEA_v100_df[,3:4])) #OK

# meta_aq <- unique(AQ_EEA_v100_df[,c(1,3:7)])
# meta_aq[duplicated(meta_aq$Longitude),]$Longitude
# meta_aq[meta_aq$Longitude %in% meta_aq[duplicated(meta_aq$Longitude),]$Longitude,]

#finish
AQ_EEA_v101_df <- AQ_EEA_v100_df
save(AQ_EEA_v101_df,file = "AQ-EEA/v.1.0.1/data/daily/AQ_EEA_v101_df.rda")


