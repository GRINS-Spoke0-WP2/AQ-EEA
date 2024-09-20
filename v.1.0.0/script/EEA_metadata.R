library(httr)

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
save(metadataEEA,file = "data/metadataEEA.Rdata")
