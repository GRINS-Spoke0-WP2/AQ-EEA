library(httr)
try(setwd("AQ-EEA/v.1.0.0"))
try(setwd("v.1.0.0"))
download.file("https://discomap.eea.europa.eu/map/fme/metadata/PanEuropean_metadata.csv",
              destfile = "data/raw_metadata.csv")

library(readr)
PanEuropean_metadata <-
  read_delim(
    "data/raw_metadata.csv",
    delim = "\t",
    escape_double = FALSE,
    col_types = cols(
      Timezone = col_skip(),
      Namespace = col_skip(),
      AirQualityStationNatCode = col_skip(),
      SamplingPoint = col_skip(),
      SamplingProces = col_skip(),
      Sample = col_skip(),
      EquivalenceDemonstrated = col_skip(),
      MeasurementEquipment = col_skip(),
      InletHeight = col_skip(),
      BuildingDistance = col_skip(),
      KerbDistance = col_skip()
    ),
    trim_ws = TRUE
  )

metadataEEA<-unique(PanEuropean_metadata[,c(1,3,5:14)])
metadataEEA<-metadataEEA[metadataEEA$Countrycode=="IT",]
metadataEEA <- unique(metadataEEA[, c(2, 7,8,9,11, 12)])
idx <- which(duplicated(metadataEEA$AirQualityStation))
a <- metadataEEA[idx, ]
a <- metadataEEA[c(idx,idx-1), ]

stazioni_corrette <- data.frame(
  AirQualityStation = c("STA.IT2245A", "STA.IT0709A", "STA.IT0740A", "STA.IT0817A", 
                        "STA.IT0867A", "STA.IT0871A", "STA.IT0888A", "STA.IT0889A", 
                        "STA.IT0950A", "STA.IT1071A", "STA.IT1090A", "STA.IT1091A", 
                        "STA.IT1097A", "STA.IT1192A", "STA.IT1264A", "STA.IT1340A", 
                        "STA.IT1383A", "STA.IT1486A", "STA.IT1575A", "STA.IT1587A", 
                        "STA.IT1742A", "STA.IT1827A", "STA.IT1829A", "STA.IT1874A", 
                        "STA.IT2129A", "STA.IT2130A", "STA.IT2133A", "STA.IT2152A", 
                        "STA.IT2170A", "STA.IT2219A", "STA.IT2289A", "STA.IT2290A", 
                        "STA.IT2291A"),
  AirQualityStationType = c("traffic", "background", "background", "background", 
                            "background", "traffic", "industrial", "background", 
                            "background", "background", "industrial", "background", 
                            "background", "industrial", "background", "background", 
                            "industrial", "traffic", "industrial", "background", 
                            "industrial", "background", "traffic", "background", 
                            "background", "background", "background", "background", 
                            "background", "background", "industrial", "background", 
                            "background")
)

stazioni_corrette <- merge(stazioni_corrette,metadataEEA)
stazioni_corrette <- stazioni_corrette[!duplicated(stazioni_corrette$AirQualityStation),]
metadataEEA <- metadataEEA[!duplicated(metadataEEA$AirQualityStation),]
metadataEEA <- metadataEEA[!metadataEEA$AirQualityStation %in% stazioni_corrette$AirQualityStation,]
metadataEEA <- rbind(metadataEEA,stazioni_corrette)
save(metadataEEA,file = "data/metadataEEA.Rdata")

#STA.IT2245A traffic 
#STA.IT0709A background 
#STA.IT0740A background 
#STA.IT0817A background 
#STA.IT0867A background 
#STA.IT0871A traffic 
#STA.IT0888A industrial 
#STA.IT0889A background 
#STA.IT0950A background 
#STA.IT1071A background 
#STA.IT1090A industrial 
#STA.IT1091A background 
#STA.IT1097A background 
#STA.IT1192A industrial 
#STA.IT1264A background 
#STA.IT1340A background 
#STA.IT1383A industrial 
#STA.IT1486A traffic 
#STA.IT1575A industrial 
#STA.IT1587A background
#STA.IT1742A industrial
#STA.IT1827A background
#STA.IT1829A traffic
#STA.IT1874A background
#STA.IT2129A background
#STA.IT2130A background
#STA.IT2133A background
#STA.IT2152A background
#STA.IT2170A background
#STA.IT2219A background
#STA.IT2289A industrial
#STA.IT2290A background
#STA.IT2291A background
