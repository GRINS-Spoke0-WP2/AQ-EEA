# changing name WE in CL
load("AQ-EEA/v.1.0.1/data/AiQuClimItaly.rda")
GRINS_AQCLIM_points_Italy <- AiQuClimItaly
names(GRINS_AQCLIM_points_Italy) <- gsub("WE_","CL_",names(GRINS_AQCLIM_points_Italy))


names(GRINS_AQCLIM_points_Italy)
summary(GRINS_AQCLIM_points_Italy)

save(GRINS_AQCLIM_points_Italy, file = "AQ-EEA/v.1.0.2/data/GRINS_AQCLIM_points_Italy.rda")
