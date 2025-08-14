# AQ_EEA v.1.0.1 created in EEA_fixing SO2 in v100
load("AQ-EEA/v.1.0.0/data/daily/AQ_EEA_v101_df.rda")
a <- summary(AQ_EEA_v101_df[,c(10,16,22,28,34,40,46,52)])

# write.table(a,
#             file = "v.1.0.0/data/descriptive_statistics.csv",
#             row.names = F,
#             sep = ";")

for (i in c(10,16,22,28,34,40,46,52)) {
  print(names(AQ_EEA_v101_df)[i])
  print(length(unique(AQ_EEA_v101_df$AirQualityStation[!is.na(AQ_EEA_v101_df[,i])])))
}

library(stargazer)
summary_df <- data.frame(
  Pollutants=substr(names(AQ_EEA_v101_df)[c(10,16,22,28,34,40,46,52)],6,10)
)
n_staz <- c()
for (i in c(10,16,22,28,34,40,46,52)) {
  n_staz <- c(n_staz,length(unique(AQ_EEA_v101_df$AirQualityStation[!is.na(AQ_EEA_v101_df[,i])])))
}
summary_df$n_staz <- n_staz
aa<- do.call(cbind, lapply(AQ_EEA_v101_df[,c(10,16,22,28,34,40,46,52)], summary))
aa<-as.data.frame(aa)
names(aa)<-substr(names(aa),6,10)
NA_i <- c()
timee <- length(unique(AQ_EEA_v101_df$time))
for (i in c(10,16,22,28,34,40,46,52)) {
  staz_i <- unique(AQ_EEA_v101_df$AirQualityStation[!is.na(AQ_EEA_v101_df[,i])])
  NA_i <- c(NA_i,sum(is.na(AQ_EEA_v101_df[AQ_EEA_v101_df$AirQualityStation %in% staz_i,i]))/(length(staz_i)*timee))
}
aa[7,]<-NA_i
row.names(aa)
stargazer(cbind(summary_df[,-1],t(aa)[,-c(2,3,5)]),summary = F,digits = 2,decimal.mark=".")
          # digit.separator="'")


#map
library(sp)
library(sf)
library(ggplot2)
reg24 <-
  st_read(dsn = "geo_tools/geo_matching/v.1.0.0/dati/confini/extract_zip/Limiti01012024/Reg01012024",
          layer = "Reg01012024_WGS84")
Italy <- st_union(reg24)
ggplot()+
  geom_sf(data=Italy)

meta_aq <- unique(AQ_EEA_v101_df[,c(3,4,6,7)])
coordinates(meta_aq)<-c("Longitude","Latitude")
meta_aq_sf <- st_as_sf(meta_aq)
st_crs(meta_aq_sf)<-4326
meta_aq_sf$AirQualityStationArea[grep("rural",meta_aq_sf$AirQualityStationArea)]<-"rural"
# meta_aq_sf <- st_transform()

ggplot()+
  geom_sf(data=Italy)+
  geom_sf(data=reg24,linewidth=0.1)+
  geom_sf(data = meta_aq_sf,aes(col=as.factor(AirQualityStationArea),
                                shape=as.factor(AirQualityStationType)))+
  scale_color_discrete(name="Station area")+scale_shape_discrete(name="Station type")+
  theme_light()+
  theme(legend.title = element_text(size = 10),#15, family = "serif"), #10
        legend.text = element_text(size = 10))+#15,family = "serif")) #10
  ggtitle(label = "Air Quality Monitoring Network",subtitle = "present in AQ.CLIM_IT1323")
ggsave("AQ-EEA/v.1.0.1/plot/localisations.pdf",width = 7,height = 5)
ggsave("AQ-EEA/v.1.0.1/plot/localisations.png",width = 7,height = 5)
aaa<-as.data.frame.matrix(table(meta_aq_sf$AirQualityStationType,meta_aq_sf$AirQualityStationArea))
stargazer(aaa,summary=F)

