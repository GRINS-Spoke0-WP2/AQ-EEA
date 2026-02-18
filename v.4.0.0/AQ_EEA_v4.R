# mettiamo insieme 2000-2012 con 2013-2023

#2000-2012
load("AQ-EEA/v.3.0.0/data/A3_fromHtoD/A32_merge/AQ_EEA_v300_df.rda")

#2013-2023
load("AQ-EEA/v.1.0.3/data/daily/AQ_EEA_v101_df.rda")

# adding NH3 to v3
nh3_names <- names(AQ_EEA_v101_df)[grep("NH3", names(AQ_EEA_v101_df))]
mm <- matrix(nrow = nrow(AQ_EEA_v300_df), ncol = length(nh3_names))
colnames(mm) <- nh3_names
AQ_EEA_v300_df <- cbind(AQ_EEA_v300_df, mm)

vn <- setdiff(names(AQ_EEA_v101_df), names(AQ_EEA_v300_df))
AQ_EEA_v101_df <- AQ_EEA_v101_df[, -which(names(AQ_EEA_v101_df) %in% vn)]

setdiff(names(AQ_EEA_v101_df), names(AQ_EEA_v300_df))
AQ_EEA_v300_df <- AQ_EEA_v300_df[, names(AQ_EEA_v101_df)]

AQ_EEA_v400_df <- rbind(AQ_EEA_v300_df, AQ_EEA_v101_df)

AQ_EEA_v400_df <- AQ_EEA_v400_df[order(AQ_EEA_v400_df$time,
                                       AQ_EEA_v400_df$Latitude,
                                       AQ_EEA_v400_df$Longitude), ]

AQCLIM_Station_registry_information <- read_csv(
  "AQ-EEA/v.3.0.0/data/A3_fromHtoD/A32_merge/AQCLIM_Station_registry_information.csv"
)

AQ_EEA_v400_df <- merge(AQ_EEA_v400_df[, -c(which(names(AQ_EEA_v400_df) %in% c("Longitude", "Latitude")))], AQCLIM_Station_registry_information)

AQ_EEA_v400_df <- AQ_EEA_v400_df[,names(AQ_EEA_v300_df)]

saveRDS(AQ_EEA_v400_df, file = "AQ-EEA/v.4.0.0/AQ_EEA_v400_df.rds")





