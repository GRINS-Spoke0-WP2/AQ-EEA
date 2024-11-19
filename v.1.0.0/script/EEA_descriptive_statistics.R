setwd("AQ-EEA")
load("v.1.0.0/data/daily/AQ_EEA_v100_df.rda")

a <- summary(AQ_EEA_v100_df[,c(10,16,22,28,34,40,46,52)])

write.table(a,
          file = "v.1.0.0/data/descriptive_statistics.csv",
          row.names = F,
          sep = ";")

for (i in c(10,16,22,28,34,40,46,52)) {
  print(names(AQ_EEA_v100_df)[i])
  print(length(unique(AQ_EEA_v100_df$AirQualityStation[!is.na(AQ_EEA_v100_df[,i])])))
}
