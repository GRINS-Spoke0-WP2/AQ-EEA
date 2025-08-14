# setwd("AQ-EEA")
# load("v.1.0.0/data/daily/AQ_EEA_v100_df.rda")
# a <- summary(AQ_EEA_v100_df[,c(10,16,22,28,34,40,46,52)])
# 
# write.table(a,
#           file = "v.1.0.0/data/descriptive_statistics.csv",
#           row.names = F,
#           sep = ";")
# 
# for (i in c(10,16,22,28,34,40,46,52)) {
#   print(names(AQ_EEA_v100_df)[i])
#   print(length(unique(AQ_EEA_v100_df$AirQualityStation[!is.na(AQ_EEA_v100_df[,i])])))
# }
# 
# library(stargazer)
# summary_df <- data.frame(
#   Pollutants=substr(names(AQ_EEA_v100_df)[c(10,16,22,28,34,40,46,52)],6,10),
# )
# n_staz <- c()
# for (i in c(10,16,22,28,34,40,46,52)) {
#   n_staz <- c(n_staz,length(unique(AQ_EEA_v100_df$AirQualityStation[!is.na(AQ_EEA_v100_df[,i])])))
# }
# summary_df$n_staz <- n_staz
# aa<- do.call(cbind, lapply(AQ_EEA_v100_df[,c(10,16,22,28,34,40,46,52)], summary))
# aa<-as.data.frame(aa)
# names(aa)<-substr(names(aa),6,10)
# aa[7,]<-aa[7,]/nrow(AQ_EEA_v100_df)
# stargazer(cbind(summary_df[,-1],t(aa)),summary = F,digits = 2)
# sum(AQ_EEA_v100_df$min_SO2<0,na.rm = T)
# sum(AQ_EEA_v100_df$q1_SO2 <0,na.rm = T)
# sum(AQ_EEA_v100_df$mean_SO2 <0,na.rm = T)