load("AQ-EEA/v.1.0.2/data/GRINS_AQCLIM_points_Italy.rda")

names(GRINS_AQCLIM_points_Italy)
length(unique(GRINS_AQCLIM_points_Italy$AirQualityStation))

load("~/Library/Mobile Documents/com~apple~CloudDocs/Lavoro/PhD Bergamo/R/GitHub/GRINS-Spoke0-WP2/AQ-EEA/v.1.0.3/data/daily/AQ_EEA_v100_df.rda")
load("~/Library/Mobile Documents/com~apple~CloudDocs/Lavoro/PhD Bergamo/R/GitHub/GRINS-Spoke0-WP2/AQ-EEA/v.1.0.3/data/daily/AQ_EEA_v101_df.rda")

length(unique(AQ_EEA_v100_df$AirQualityStation))
length(unique(AQ_EEA_v101_df$AirQualityStation))
