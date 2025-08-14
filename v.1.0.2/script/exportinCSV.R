load("AQ-EEA/v.1.0.2/data/GRINS_AQCLIM_points_Italy.rda")

for (y in c(2013,2015,2017,2019,2021,2023)) {
  d <- as.Date(paste0(y,"-01-01"))
  d_end <- as.Date(paste0(y+1,"-12-31"))
  sub <- subset(GRINS_AQCLIM_points_Italy,GRINS_AQCLIM_points_Italy$time > d & GRINS_AQCLIM_points_Italy$time < d_end)
  write.table(
    cbind(
      sub[, 1:2],
      format(sub[, c(3:4)], digits = 9, scientific =
               F),
      sub[, 5:7],
      format(sub[, c(8:64)], digits = 4, scientific =
               T)
    ),
    file = paste0("AQ-EEA/v.1.0.2/data/GRINS_AQCLIM_points_Italy_y",y,y+1,".csv"), #adjust 2023
    row.names = F,
    col.names = names(sub),
    quote = F,
    sep = ",",
    dec = "."
  )
}


