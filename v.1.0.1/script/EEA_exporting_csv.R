#AQ_EEA_v101_df
# load("AQ-EEA/v.1.0.1/data/daily/AQ_EEA_v101_df.rda")
# AQ_EEA_Level2_v101 <- AQ_EEA_v101_df
# write.table(
#   cbind(
#     AQ_EEA_Level2_v101[, 1:2],
#     format(
#       AQ_EEA_Level2_v101[, c(3:4)],
#       digits = 9,
#       scientific = F
#     ),
#     AQ_EEA_Level2_v101[, 5:7],
#     format(AQ_EEA_Level2_v101[, c(8:55)])
#   ),
#   file = "AQ-EEA/v.1.0.1/data/AQ_EEA_Level2_v101.csv",
#   row.names = F,
#   col.names = names(AQ_EEA_Level2_v101),
#   quote = F,
#   sep = ",",
#   dec = "."
# )
# save(AQ_EEA_Level2_v101,file="AQ-EEA/v.1.0.1/data/AQ_EEA_Level2_v101.rda")

#AQ_CLIM ####
load("AQ-EEA/v.1.0.1/data/AiQuClimItaly.rda")
AiQuClimItaly <- AQ.CLIM_IT1323
save(AiQuClimItaly,file = "AQ-EEA/v.1.0.1/data/AiQuClimItaly.rda")
AiQuClimItaly$WE_winddir<-as.factor(AiQuClimItaly$WE_winddir)
for (y in c(2013,2015,2017,2019,2021,2023)) {
  d <- as.Date(paste0(y,"-01-01"))
  d_end <- as.Date(paste0(y+1,"-12-31"))
  sub <- subset(AiQuClimItaly,AiQuClimItaly$time > d & AiQuClimItaly$time < d_end)
  write.table(
  cbind(
    sub[, 1:2],
    format(sub[, c(3:4)], digits = 9, scientific =
             F),
    sub[, 5:7],
    format(sub[, c(8:64)], digits = 4, scientific =
             T)
  ),
  file = paste0("AQ-EEA/v.1.0.1/data/AiQuClimItaly_y",y,y+1,".csv"), #adjust 2023
  row.names = F,
  col.names = names(sub),
  quote = F,
  sep = ",",
  dec = "."
)
}
#one file
write.table(
  cbind(
    AiQuClimItaly[, 1:2],
    format(AiQuClimItaly[, c(3:4)], digits = 9, scientific =
             F),
    AiQuClimItaly[, 5:7],
    format(AiQuClimItaly[, c(8:64)], digits = 4, scientific =
             T)
  ),
  file = "AQ-EEA/v.1.0.1/data/AiQuClimItaly.csv",
  row.names = F,
  col.names = names(AiQuClimItaly),
  quote = F,
  sep = ",",
  dec = "."
)


