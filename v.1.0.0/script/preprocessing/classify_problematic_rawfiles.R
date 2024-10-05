#This script take csv files downloaded and conver it in R dataframe
#Every output is one station, one pollutant, one year

library(doParallel)
library(foreach)
library(httr)
registerDoParallel(cores = detectCores())
library(lubridate)
setwd("AQ-EEA")
rm(list = ls())
gc()

EEAfiles <-
  list.files(path = "data/raw",
             pattern = ".csv")
pol_staz_year <- foreach (i = EEAfiles, .combine = rbind) %dopar% {
  print(which(EEAfiles == i))
  source("script/functions.R")
  df_EEA <- open_raw(i, "data/raw")
  df_EEA$date <- as_date(df_EEA$DatetimeBegin)
  dd <- df_EEA$date[df_EEA$AveragingTime == "day"]
  dt <- unique(df_EEA$date[duplicated(df_EEA$date)])
  d <- intersect(dt, dd)
  if (length(d) >= 1) {
    duplicated_date <- "yes"
  } else{
    duplicated_date <- "no"
  }
  ddh <- df_EEA$DatetimeBegin[df_EEA$AveragingTime != "day"]
  if (any(duplicated(ddh))) {
    duplicated_hour <- "yes"
  } else{
    duplicated_hour <- "no"
  }
  naperc <- sum(is.na(df_EEA$Concentration)) / nrow(df_EEA)
  avg_time <- unique(df_EEA$AveragingTime)
  avg_time <- avg_time[order(avg_time)]
  pol_staz_year <- data.frame(
    pol = unique(df_EEA$AirPollutant),
    staz = unique(df_EEA$AirQualityStation),
    year = unique(substr(df_EEA$DatetimeBegin, 1, 4)),
    time_res = paste(avg_time, collapse = "_"),
    na_perc = naperc,
    n_row = nrow(df_EEA),
    name_file = i,
    duplicated_date = duplicated_date,
    duplicated_hour = duplicated_hour
  )
  pol_staz_year
}
save(pol_staz_year,
     file = "data/preprocessing/list_raw_files.Rdata")

duplicated_dates <-
  pol_staz_year$name_file[pol_staz_year$duplicated_date == "yes" |
                            pol_staz_year$duplicated_hour == "yes"]
save(duplicated_dates, file = "data/preprocessing/duplicated_rawfiles.Rdata")

double_stations <-
  pol_staz_year[duplicated(pol_staz_year[, c(1:3)]),]
save(double_stations,
     file = "data/preprocessing/double_stations.Rdata")

#classify problematic files (double)
names(double_stations)[-c(1:3)] <-
  paste0("duplicated_", names(double_stations)[-c(1:3)])
problematic_stations <-
  merge(pol_staz_year[!duplicated(pol_staz_year[, c(1:3)]),], double_stations)

source("script/functions.R")

removing_files <- c() #files to not be used
complementary_files <- list() #files complementary
for (i in 1:nrow(problematic_stations)) {
  #1a
  file1 <- problematic_stations$name_file[i]
  df_EEA1 <- open_raw(file1, "data/raw")
  file2 <- problematic_stations$duplicated_name_file[i]
  df_EEA2 <- open_raw(file2, "data/raw")
  
  #stessa risoluzione
  if (same_res(df_EEA1, df_EEA2)) {
    #2a
    if (same_rows(df_EEA1, df_EEA2, i)) {
      #3a
      if (same_values(df_EEA1, df_EEA2)) {
        #4a: if they are the same
        removing_files <- c(removing_files, file2)
      } else {
        #if they are not the same
        if (n_val(df_EEA1, df_EEA2)) {
          #if they don't have the same number of missingness
          if (sum(df_EEA1$Validity %in% c(1, 2, 3)) >
              sum(df_EEA2$Validity %in% c(1, 2, 3))) {
            removing_files <- c(removing_files, file2)
          }
          else {
            removing_files <- c(removing_files, file1)
          }
        }
        else {
        # if they don't have the same number of missingness
        print(i)
        stop(
          paste(
            "iteration",
            i,
            "file 1:",
            file1,
            "file 2:",
            file2,
            "have same temporal resolution, same number of missing but different concentrations"
          )
        )
        }
      }
    } else {
      #if they don't have the same number of rows
      if (time_nointers(df_EEA1, df_EEA2)) {
        #they are complementary
        complementary_files[[length(complementary_files) + 1]] <-
          c(file1, file2, "not_overlap", "same_res")
      } else {
        if (same_values_diff_tempres(df_EEA1, df_EEA2)) {
          complementary_files[[length(complementary_files) + 1]] <-
            c(file1, file2, "overlap", "same_res")
        } else {
          print(i)
          stop(
            paste(
              "iteration",
              i,
              "file 1:",
              file1,
              "file 2:",
              file2,
              "have same resolution but different values at the same time istance"
            )
          )
        }
      }
    }
  }
  else {
    #diversa risoluzione
    if (one_in_other(df_EEA1, df_EEA2)) {
      #uno nell altro
      if (all(df_EEA1$DatetimeBegin %in% df_EEA2$DatetimeBegin)) {
        removing_files <- c(removing_files, file1)
      }
      else {
        removing_files <- c(removing_files, file2)
      }
    } else {
      #uno non nell altro
      if (time_nointers(df_EEA1, df_EEA2)) {
        complementary_files[[length(complementary_files) + 1]] <-
          c(file1, file2, "not_overlap", "diff_res")
      } else {
        if (same_values_diff_tempres(df_EEA1, df_EEA2)) {
          complementary_files[[length(complementary_files) + 1]] <-
            c(file1, file2, "overlap", "diff_res")
        } else {
          stop(paste("iteration:", i, "is a new situation"))
        }
      }
    }
  }
}

save(removing_files,file="data/preprocessing/removing_files.Rdata")
save(complementary_files,file="data/preprocessing/complementary_files.Rdata")
