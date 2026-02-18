library(sf)
library(sp)
library(readr)
library(arrow)
library(lubridate)
library(doParallel)
library(dplyr)

setwd("AQ-EEA/v.3.0.0")

df_parquet <- read.csv("data/ParquetFilesUrls.csv")
for (i in 1:nrow(df_parquet)) {
  ni <- df_parquet$ParquetFileUrl[i]
  ni <- gsub(
    "https://eeadmz1batchservice02.blob.core.windows.net/airquality-p-airbase/IT/",
    "",
    ni
  )
  download.file(df_parquet$ParquetFileUrl[i], destfile = file.path("data/raw", ni))
}

parquet_files <- list.files("data/raw")
for (i in parquet_files) {
  df <- read_parquet(file.path("data/raw", i))
  if (nrow(df) == 0) {
    file.remove(file.path("data/raw", i))
    next
  }
  df$AirQualityStation <- paste0("STA.", substr(i, 5, 11))
  df$Start <- with_tz(df$Start, "UTC")
  df$End <- with_tz(df$End, "UTC")
  write.csv(df,
            file = paste0("data/raw/csv", "/", substr(i, 1, nchar(i) - 8), ".csv"),
            row.names = F)
}

# from parquet to CSV
old_files <- list.files("data/raw", pattern = ".parquet")
for (i in old_files) {
  df <- read_parquet(file.path("data/raw", i))
  if (nrow(df) == 0) {
    file.remove(file.path("data/raw", i))
    next
  }
  df$AirQualityStation <- paste0("STA.", substr(i, 5, 11))
  df$Start <- with_tz(df$Start, "UTC")
  df$End <- with_tz(df$End, "UTC")
  write.csv(df,
            file = paste0("data/raw/csv", "/", substr(i, 5, 11), ".csv"),
            row.names = F)
}

# A. AQ_EEA: Air Quality data ####
A1_path_d_csv <- "data/raw/csv"

A2_path <- "data/A2_prepocessing"
A22_path_1s1p1t <- file.path(A2_path, "A22_1s1p1t")
dir.create(A22_path_1s1p1t,
           recursive = T,
           showWarnings = F)
A23_path_1p1t <- file.path(A2_path, "A23_1p1t")
dir.create(A23_path_1p1t, recursive = T, showWarnings = F)

A24_path_1p1t_sub <- file.path(A2_path, "A24_1p1t_sub")
dir.create(A24_path_1p1t_sub,
           recursive = T,
           showWarnings = F)

A3_path <- file.path("data/A3_fromHtoD")
A31_path_1p1s <- file.path(A3_path, "A31_HtoD_1p1s")
dir.create(A31_path_1p1s, recursive = T, showWarnings = F)

A32_path_merge <- file.path(A3_path, "A32_merge")
dir.create(A32_path_merge,
           recursive = T,
           showWarnings = F)




## A.2. pre-processing EEA data ####
cat("starting A.2 pre-processing EEA data")

open_raw <- function(i, path) {
  exampleEEA <- read.csv(paste0(path, "/", i))
  if (class(exampleEEA) != "data.frame") {
    stop(paste("the CSV file", i, "is not a dataframe"))
  }
  if (nrow(exampleEEA) == 0) {
    stop(paste("the CSV file", i, "is empty"))
  }
  names(exampleEEA)[which(names(exampleEEA) == "Pollutant")] <- "AirPollutant"
  names(exampleEEA)[which(names(exampleEEA) == "Start")] <- "DatetimeBegin"
  names(exampleEEA)[which(names(exampleEEA) == "End")] <- "DatetimeEnd"
  names(exampleEEA)[which(names(exampleEEA) == "Value")] <- "Concentration"
  names(exampleEEA)[which(names(exampleEEA) == "AggType")] <- "AveragingTime"
  
  if (class(exampleEEA) == "data.frame") {
    df_EEA <-
      exampleEEA[, c(
        "AirQualityStation",
        "AirPollutant",
        "Concentration",
        "DatetimeBegin",
        "DatetimeEnd",
        "Validity",
        "Verification",
        "AveragingTime"
      )]
  }
  #checking and removing empty fields
  staz <- unique(df_EEA$AirQualityStation)
  if (any("" %in% staz)) {
    staz <- staz[-which(staz == "")]
    df_EEA <- df_EEA[df_EEA$AirQualityStation != "", ]
  }
  if (length(staz) != 1) {
    print(i)
    stop(paste("in", i, "more than 1 stations"))
  }
  poll <- unique(df_EEA$AirPollutant)
  if (any("" %in% poll)) {
    poll <- poll[-which(poll == "")]
    df_EEA <- df_EEA[df_EEA$AirPollutant != "", ]
  }
  if (length(poll) != 1) {
    stop(paste("in", i, "more than 1 pollutant"))
  }
  if (any("" %in% c(unique(df_EEA$DatetimeBegin), unique(df_EEA$DatetimeEnd)))) {
    print(df_EEA[df_EEA$DatetimeBegin == "" |
                   df_EEA$DatetimeEnd == "" , ])
    df_EEA <-
      df_EEA[df_EEA$DatetimeBegin != "" |
               df_EEA$DatetimeEnd != "", ]
  }
  #converting time from character
  # h <- which(df_EEA$AveragingTime %in% c("hourly", "var"))
  df_EEA$DatetimeBegin <- as_datetime(df_EEA$DatetimeBegin)
  # df_EEA$DatetimeBegin <-
  #   with_tz(df_EEA$DatetimeBegin, tz = "Etc/GMT-1")
  df_EEA$DatetimeEnd <- as_datetime(df_EEA$DatetimeEnd)
  # df_EEA$DatetimeEnd <-
  #   with_tz(df_EEA$DatetimeEnd, tz = "Etc/GMT-1")
  # year <- substr(df_EEA$DatetimeBegin, 1, 4)
  # year1 <- unique(year)
  # if (length(year1) != 1) {
  #   stop(paste(i, "with more than 1 year"))
  # }
  return(df_EEA)
}

EEAfiles <- list.files(A1_path_d_csv, pattern = ".csv")

### A.2.1. identifying problematic files ####
cat("Start A.2.1. - identifying problematic files")

same_res <-
  function(df_EEA1, df_EEA2) {
    length(setdiff(
      unique(df_EEA1$AveragingTime),
      unique(df_EEA2$AveragingTime)
    )) == 0 &
      length(setdiff(
        unique(df_EEA2$AveragingTime),
        unique(df_EEA1$AveragingTime)
      )) == 0
  }

same_rows <- function(df_EEA1, df_EEA2, i) {
  problematic_stations$n_row[i] == problematic_stations$duplicated_n_row[i]
}

n_val <- function(df_EEA1, df_EEA2) {
  sum(df_EEA1$Validity %in% c(1, 2, 3)) != sum(df_EEA2$Validity %in% c(1, 2, 3))
}

same_values <- function(df_EEA1, df_EEA2) {
  sum(c(df_EEA1$Concentration - df_EEA2$Concentration), na.rm = T) ==
    0 &
    length(setdiff(df_EEA1$DatetimeBegin[is.na(df_EEA1$Concentration)], df_EEA2$DatetimeBegin[is.na(df_EEA2$Concentration)])) ==
    0 &
    length(setdiff(df_EEA1$DatetimeBegin[is.na(df_EEA2$Concentration)], df_EEA2$DatetimeBegin[is.na(df_EEA1$Concentration)])) ==
    0
}

time_nointers <-
  function(df_EEA1, df_EEA2) {
    length(intersect(df_EEA1$DatetimeBegin, df_EEA2$DatetimeBegin)) ==
      0
  }

same_values_diff_tempres <-
  function(df_EEA1, df_EEA2) {
    sum(c(df_EEA1$Concentration[df_EEA1$DatetimeBegin %in% intersect(df_EEA1$DatetimeBegin, df_EEA2$DatetimeBegin)] -
            df_EEA2$Concentration[df_EEA2$DatetimeBegin %in% intersect(df_EEA1$DatetimeBegin, df_EEA2$DatetimeBegin)]), na.rm = T) == 0
  }

one_in_other <-
  function(df_EEA1, df_EEA2) {
    all(df_EEA1$DatetimeBegin %in% df_EEA2$DatetimeBegin) |
      all(df_EEA2$DatetimeBegin %in% df_EEA1$DatetimeBegin)
  }

duplicated_dates_correction <-
  function(df_EEA) {
    df_EEA$date <- as_date(df_EEA$DatetimeBegin)
    dd <- df_EEA$date[df_EEA$AveragingTime == "day"]
    dt <- unique(df_EEA$date[duplicated(df_EEA$date)])
    dl <- intersect(dt, dd)
    dl <- dl[order(dl)]
    for (d in dl) {
      d <- as.Date(d)
      sub <- df_EEA[df_EEA$date == d, ]
      if (any(c("hour", "var") %in% unique(sub$AveragingTime)) &
          "day" %in% unique(sub$AveragingTime)) {
        DatetimeBegin <-
          seq.POSIXt(
            from = as_datetime(paste0(d, " 00:00:00"), tz = "Etc/GMT-1"),
            to = as_datetime(paste0(d, " 23:00:00"), tz =
                               "Etc/GMT-1"),
            by = "hour"
          )
        DatetimeEnd <- DatetimeBegin + 3600
        sub <- merge(
          sub,
          data.frame(DatetimeBegin = DatetimeBegin, DatetimeEnd = DatetimeEnd),
          all.y = T
        )
        t_excl <- lag_na(sub)
        if (length(t_excl) != 0 && t_excl == d) {
          df_EEA <- df_EEA[df_EEA$AveragingTime == "day", ]
        } else{
          df_EEA <- df_EEA[df_EEA$AveragingTime != "day", ]
        }
      }
    }
    return(df_EEA)
  }

pol_staz_year <- foreach (i = EEAfiles, .combine = rbind) %dopar% {
  #i = EEAfiles[1]
  #i = EEAfiles[1]
  # source("AQ-EEA/v.2.0.0/script/functions.R")
  # i, path = A1_path_du
  df_EEA <- open_raw(i, A1_path_d_csv)
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
    # year = unique(substr(df_EEA$DatetimeBegin, 1, 4)),
    time_res = paste(avg_time, collapse = "_"),
    na_perc = naperc,
    n_row = nrow(df_EEA),
    name_file = i,
    duplicated_date = duplicated_date,
    duplicated_hour = duplicated_hour
  )
  pol_staz_year
}

duplicated_dates <-
  pol_staz_year$name_file[pol_staz_year$duplicated_date == "yes" |
                            pol_staz_year$duplicated_hour == "yes"]
double_stations <-
  pol_staz_year[duplicated(pol_staz_year[, c(1:3)]), ]

if (!is.null(double_stations)) {
  names(double_stations)[-c(1:3)] <-
    paste0("duplicated_", names(double_stations)[-c(1:3)])
}
problematic_stations <-
  merge(pol_staz_year[!duplicated(pol_staz_year[, c(1:3)]), ], double_stations)

### A.2.2. fixing problematic stations ####
cat("Start A.2.2. - fixing problematic stations")

if (nrow(problematic_stations) == 0 &
    length(duplicated_dates) == 0) {
  print("no problematic stations or dates in the EEA raw data")
  # normal files
  foreach (i = EEAfiles) %dopar% {
    df_EEA <- open_raw(i, A1_path_d_csv)
    save(#require uniqueness if not overwrite
      df_EEA, file = file.path(
        A22_path_1s1p1t,
        paste0(
          unique(df_EEA$AirQualityStation),
          "_",
          unique(df_EEA$AirPollutant),
          "_",
          unique(substr(df_EEA$DatetimeBegin, 1, 4))
          ,
          ".rda"
        )
      ))
    rm(exampleEEA)
  }
} else{
  removing_files <- c() #files to not be used
  complementary_files <- list() #files complementary
  if (nrow(problematic_stations) != 0) {
    for (i in 1:nrow(problematic_stations)) {
      #1a
      file1 <- problematic_stations$name_file[i]
      df_EEA1 <- open_raw(file1, A1_path_d_csv)
      file2 <- problematic_stations$duplicated_name_file[i]
      df_EEA2 <- open_raw(file2, A1_path_d_csv)
      
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
  }
  EEAfiles <- EEAfiles[which(!EEAfiles %in% removing_files)]
  EEAfiles <- EEAfiles[which(!EEAfiles %in% duplicated_dates)]
  EEAfiles <-
    EEAfiles[which(!EEAfiles %in% unlist(complementary_files))]
  
  # normal files
  foreach (i = EEAfiles) %dopar% {
    df_EEA <- open_raw(i, A1_path_d_csv)
    years <- unique(substr(df_EEA$DatetimeBegin, 1, 4))
    for (y in years) {
      sub_EEA <- df_EEA[format(df_EEA$DatetimeBegin, "%Y") == y, ]
      save(#require uniqueness if not overwrite
        sub_EEA, file = file.path(
          A22_path_1s1p1t,
          paste0(
            unique(sub_EEA$AirQualityStation),
            "_",
            unique(sub_EEA$AirPollutant),
            "_",
            y
            ,
            ".rda"
          )
        ))
    }
    rm(df_EEA)
  }
  
  #problematic stations (duplicated dates)
  EEAfiles <- duplicated_dates
  EEAfiles <- EEAfiles[!EEAfiles %in% unlist(complementary_files)]
  
  foreach (i = EEAfiles) %dopar% {
    df_EEA <- open_raw(i, A1_path_d_csv)
    years <- unique(substr(df_EEA$DatetimeBegin, 1, 4))
    for (y in years) {
      sub_EEA <- df_EEA[format(df_EEA$DatetimeBegin, "%Y") == y, ]
      sub_EEA <- duplicated_dates_correction(sub_EEA)
      save(#require uniqueness if not overwrite
        sub_EEA, file = file.path(
          A22_path_1s1p1t,
          paste0(
            unique(sub_EEA$AirQualityStation),
            "_",
            unique(sub_EEA$AirPollutant),
            "_",
            y
            ,
            ".rda"
          )
        ))
      rm(sub_EEA)
    }
  }
  
  #problematic stations (complemetary files)
  if (length(complementary_files) > 0) {
    foreach (i = 1:length(complementary_files)) %dopar% {
      file1 <- complementary_files[[i]][1]
      file2 <- complementary_files[[i]][2]
      if (complementary_files[[i]][3] == "overlap") {
        overlap <- TRUE
      } else{
        overlap <- FALSE
      }
      if (complementary_files[[i]][4] == "same_res") {
        same_res <- TRUE
      } else{
        same_res <- FALSE
      }
      df_EEA1 <- open_raw(file1, A1_path_d_csv)
      if (file1 %in% duplicated_dates) {
        df_EEA1 <- duplicated_dates_correction(df_EEA1)
        df_EEA1 <- df_EEA1[, -which(names(df_EEA1) == "date")]
      }
      df_EEA2 <- open_raw(file2, A1_path_d_csv)
      if (file2 %in% duplicated_dates) {
        df_EEA2 <- duplicated_dates_correction(df_EEA2)
        df_EEA2 <- df_EEA2[, -which(names(df_EEA2) == "date")]
      }
      if (!overlap) {
        df_EEA <- rbind(df_EEA1, df_EEA2)
      } else if (same_res) {
        overlap_time <- intersect(df_EEA1$DatetimeBegin, df_EEA2$DatetimeBegin)
        df_EEA1 <-
          df_EEA1[!df_EEA1$DatetimeBegin %in% overlap_time, ]
        df_EEA <- rbind(df_EEA1, df_EEA2)
      } else {
        overlap_time <- intersect(df_EEA1$DatetimeBegin, df_EEA2$DatetimeBegin)
        res <- c("hour", "var", "day")
        for (d in overlap_time) {
          nres1 <-
            which(res == df_EEA1$AveragingTime[df_EEA1$DatetimeBegin == d])
          nres2 <-
            which(res == df_EEA2$AveragingTime[df_EEA2$DatetimeBegin == d])
          if (nres1 <= nres2) {
            df_EEA2 <- df_EEA2[!df_EEA2$DatetimeBegin == d, ]
          } else {
            df_EEA1 <- df_EEA1[!df_EEA1$DatetimeBegin == d, ]
          }
        }
        overlap_time <- intersect(as_date(df_EEA1$DatetimeBegin),
                                  as_date(df_EEA2$DatetimeBegin))
        for (d in overlap_time) {
          res1 <- unique(df_EEA1$AveragingTime[as_date(df_EEA1$DatetimeBegin) == d])
          if (all(res1 %in% c("hour", "var"))) {
            res1 <- res1[1]
          }
          nres1 <-
            which(res == res1)
          res2 <- unique(df_EEA2$AveragingTime[as_date(df_EEA2$DatetimeBegin) == d])
          if (all(res2 %in% c("hour", "var"))) {
            res2 <- res2[1]
          }
          nres2 <-
            which(res == res2)
          if (nres1 <= nres2) {
            df_EEA2 <- df_EEA2[as_date(df_EEA2$DatetimeBegin) != d, ]
          } else {
            df_EEA1 <- df_EEA1[as_date(df_EEA1$DatetimeBegin) != d, ]
          }
        }
        df_EEA <- rbind(df_EEA1, df_EEA2)
      }
      save(#require uniqueness if not overwrite
        df_EEA, file = file.path(
          A22_path_1s1p1t,
          paste0(
            unique(df_EEA$AirQualityStation),
            "_",
            unique(df_EEA$AirPollutant),
            "_",
            unique(substr(df_EEA$DatetimeBegin, 1, 4))
            ,
            ".rda"
          )
        ))
      rm(df_EEA, df_EEA1, df_EEA2)
    }
  }
}

### A.2.3. All stations,1t_1p ####
cat("Start A.2.3 - Bind all stations into same time and pollutant")

# rm(list = setdiff(ls(), c("length_window", ls()[grep("date", ls())], ls()[grep("path", ls())])))
gc()

EEAfiles <-
  list.files(path = A22_path_1s1p1t, pattern = ".rda")

POL_considered = c(10, 38, 8, 5, 1, 7, 6001, 35)
for (i in EEAfiles) {
  # i <- EEAfiles[1]
  # print(which(EEAfiles == i))
  load(file.path(A22_path_1s1p1t, i))
  if("sub_EEA" %in% ls()){
    df_EEA <- sub_EEA
    rm(sub_EEA)}
  pol <- unique(df_EEA$AirPollutant)
  if(!pol %in% POL_considered){
    file.remove(file.path(A22_path_1s1p1t, i))
    rm(df_EEA)
    next
  }
  if (length(pol) == 0) {
    print(i)
    stop("the pollutant field is empty")
  }
  avg_time <- unique(df_EEA$AveragingTime)
  if (i == EEAfiles[1]) {
    POL <- pol
    AVG_TIME <- avg_time
  } else{
    POL <- c(POL, setdiff(pol, POL))
    AVG_TIME <- c(AVG_TIME, setdiff(avg_time, AVG_TIME))
  }
  rm(df_EEA)
}

df_POL_inf <- data.frame(
  POL = c(10, 38, 8, 5, 1, 7, 6001, 35),
  ID_POL = c("CO", "NO", "NO2", "PM10", "SO2", "O3", "PM2.5", "NH3")
)
df_POL <- merge(as.data.frame(POL), df_POL_inf, all.x = T)
names(df_POL)[1] <- "AirPollutant"

df_AVGTIME <- data.frame(ID_AVGTIME = c(1:length(AVG_TIME)), AveragingTime = AVG_TIME)

df_POL$ID_list <- 1:nrow(df_POL)
EEARfiles <-
  list.files(path = A22_path_1s1p1t, pattern = ".rda")
EEARfiles_p <- list()
for (p in df_POL$AirPollutant) {
  EEARfiles_p[[df_POL$ID_list[df_POL$AirPollutant == p]]] <-
    EEARfiles[grep(paste0("_", p, "_"), EEARfiles)]
}
sum(sapply(EEARfiles_p, length))
# #WATCH OUT FOR NAME CONTAINED IN OTHER NAME e.g. NO and NO2, they have to be fixed manually
# NO2_id <- df_POL$ID_list[df_POL$ID_POL=="NO2"]
# NO_n <- df_POL$AirPollutant[df_POL$ID_POL=="NO"]
# EEARfiles_p[[NO2_id]] <- EEARfiles_p[[NO2_id]][-grep(paste0("_",NO_n,"_"), EEARfiles_p[[NO2_id]])]
# sum(sapply(EEARfiles_p, length)) #OK
length(EEARfiles)
try(rm(df_EEA))
# partiamo dal 2000
for (i in 1:length(EEARfiles_p)) {
  print(paste("Pollutant", df_POL$ID_POL[i]))
  EEARfiles_pi <- EEARfiles_p[[i]]
  years_inc <- unique(substr(EEARfiles_pi,nchar(EEARfiles_pi)-7,nchar(EEARfiles_pi)-4))
  years_inc <- years_inc[as.numeric(years_inc) %in% 2000:2026]
  for (y in years_inc) {
    # print(paste("Start: Year", (y)))
    EEARfiles_p_y <-
      EEARfiles_pi[grep(paste0(y, ".rda"), EEARfiles_pi)]
    if (length(EEARfiles_p_y) > 0) {
      df_EEA <-
        foreach (j = EEARfiles_p_y, .combine = rbind) %dopar% {
          load(file.path(A22_path_1s1p1t, j))
          if("sub_EEA" %in% ls()){
            df_EEA <- sub_EEA
            rm(sub_EEA)}
          df_EEA <-
            merge(df_AVGTIME, merge(df_POL, df_EEA, all.y =
                                      T) , all.y = T)
          df_EEA <-
            df_EEA[, c(
              "AirQualityStation",
              "DatetimeBegin",
              "ID_AVGTIME",
              "ID_POL",
              "Concentration",
              "Validity",
              "Verification"
            )]
          df_EEA
        }
      save(df_EEA, file = file.path(A23_path_1p1t, paste0(df_POL$ID_POL[i], "_", y, ".rda")))
      rm(df_EEA)
      gc()
    }
  }
}


### A.2.4. Subsetting data ####
cat("Start A.2.4 - Subsetting EEA data")

# rm(list = setdiff(ls(), c("length_window", ls()[grep("date", ls())], ls()[grep("path", ls())])))
gc()

EEA_files <-
  list.files(A23_path_1p1t, pattern = ".rda")
EEA_short <- lapply(EEA_files, function(x) {
  nc <- nchar(x)
  substr(x, 1, nc - 4)
})
EEA_short <- unlist(EEA_short)
pol <-
  unique(sapply(EEA_short, function(x)
    substring(x, 1, nchar(x) - 5)))
pol_thr <-
  data.frame(
    pol = c("CO", "NH3", "NO", "NO2", "O3", "PM10", "PM2.5", "SO2"),
    upp_b = c(100, 50, 1000, 1000, 1000, 2630, 980, 10000)
  )

foreach(p = pol) %dopar% {
  EEA_pol <- EEA_files[grepl(paste0(p, "_"), EEA_files)]
  thr <- pol_thr$upp_b[pol_thr$pol == p]
  for (EEA_y in EEA_pol) {
    print(EEA_y)
    load(file.path(A23_path_1p1t, EEA_y))
    df_EEA <-
      df_EEA[df_EEA$Validity %in% c(1, 2, 3), ] #tolti tutti i NA
    df_EEA <- df_EEA[df_EEA$Concentration > 0, ] #tolti tutti i NA
    df_EEA <- df_EEA[df_EEA$Concentration < thr, ]
    save(df_EEA, file = file.path(A24_path_1p1t_sub, EEA_y))
  }
}

## A.3. from H to D EEA data ####
cat("Start A.3 - EEA data from hourly to daily")

# rm(list = setdiff(ls(), c("length_window", ls()[grep("date", ls())], ls()[grep("path", ls())])))
gc()

### A.3.1. 1 pollutant 1 station ####
cat("Start A.3.1 - 1 pollutant 1 station")

# from v.1.0.2

lag_na <- function(sub) {
  sub$lag_na <- NA
  day   <- as.Date(format(sub$DatetimeBegin, "%Y-%m-%d"))
  is_na <- is.na(sub$Concentration)
  new_day <- c(TRUE, day[-1] != day[-length(day)])
  grp <- cumsum(!is_na | new_day)
  sub$lag_na <- ifelse(is_na, ave(is_na, grp, FUN = cumsum), 0L)
  # sub$lag_na <- NA
  # sub$lag_na[1] <- 0
  # if (is.na(sub$Concentration[1])) {
  #   sub$lag_na[1] <- 1
  # }
  # for (i in 2:nrow(sub)) {
  #   if (is.na(sub$Concentration[i]))
  #   {
  #     sub$lag_na[i] <- sub$lag_na[i - 1] + 1
  #   } else{
  #     sub$lag_na[i] <- 0
  #   }
  #   if (as_date(sub$DatetimeBegin[i]) != as_date(sub$DatetimeBegin[i -
  #                                                                  1]) &
  #       sub$lag_na[i] != 0)
  #   {
  #     sub$lag_na[i] <- sub$lag_na[i] - sub$lag_na[i - 1]
  #   }
  # }
  date_tobe_excl <-
    unique(as_date(sub$DatetimeBegin[sub$lag_na > 6]))
  return(date_tobe_excl)
}

mixed <- function(sub, s) {
  sub_d <- sub[sub$ID_AVGTIME == 2, ]
  sub_h <- sub[sub$ID_AVGTIME %in% c(1), ]
  date_d <- unique(as_date(sub_d$DatetimeBegin))
  date_h <- unique(as_date(sub_h$DatetimeBegin))
  same_day <- as.Date(intersect(date_d, date_h))
  if (length(same_day) != 0) {
    stop(paste(s, as.Date(same_day), "with different temporal resolution"))
  }
  mescolato_df <- list()
  mescolato_df[[1]] <- sub_d
  mescolato_df[[2]] <- sub_h
  return(mescolato_df)
}

daily <- function(sub, s) {
  EEA_daily <- sub %>%
    group_by(as_date(DatetimeBegin)) %>%
    summarise(
      min = min(Concentration),
      q1 = quantile(Concentration, probs = .25),
      mean = mean(Concentration),
      med = median(Concentration),
      q3 = quantile(Concentration, probs = .75),
      max = max(Concentration)
    )
  EEA_daily$AirQualityStation <- s
  names(EEA_daily)[c(1, 8)] <- c("time", "AirQualityStation")
  EEA_daily <- EEA_daily[, c(8, 1:7)]
  names(EEA_daily)[-c(1, 2)] <-
    paste0(names(EEA_daily)[-c(1, 2)], "_", p)
  EEA_daily <- as.data.frame(EEA_daily)
  EEA_daily_uncertainty <- EEA_daily
  EEA_daily_uncertainty[!is.na(EEA_daily[, 3]), -c(1, 2)] <- 0
  EEA_daily_uncertainty[is.na(EEA_daily[, 3]), -c(1, 2)] <- NA
  names(EEA_daily_uncertainty)[-c(1, 2)] <- paste0("sd_", names(EEA_daily_uncertainty)[-c(1, 2)])
  return(list(EEA_daily = EEA_daily, EEA_daily_uncertainty = EEA_daily_uncertainty))
}

hourly <- function(sub, s) {
  DatetimeBegin <- seq.POSIXt(
    from = as.POSIXct(paste0(as.character(min(
      as_date(sub$DatetimeBegin)
    )), " 00:00:00"), tz = "Etc/GMT-1"),
    to = as.POSIXct(paste0(as.character(max(
      as_date(sub$DatetimeBegin)
    )), " 23:00:00"), tz = "Etc/GMT-1"),
    by = "hours"
  )
  sub <- merge(data.frame(DatetimeBegin), sub, all.x = T)
  sub$AirQualityStation <- s
  date_tobe_excl <- lag_na(sub)
  sub_list <- imputation(sub, s, date_tobe_excl)
  if (class(sub_list) == "list") {
    if (nrow(sub_list[[1]]) > 0) {
      daily_list <- daily_average(sub_list, s, date_tobe_excl)
      return(daily_list)
    } else{
      return(sub_list)
    }
  } else{
    return(sub_list)
  }
}

imputation <- function(sub, s, date_tobe_excl) {
  if (length(unique(sub$Concentration[!is.na(sub$Concentration)])) ==
      1) {
    # QUESTA NO !
    sub$Concentration <-
      unique(sub$Concentration[!is.na(sub$Concentration)])
    sub$time <- as_date(sub$DatetimeBegin)
    print(paste0(s, " all equal"))
    return(sub)
  } else if (length(date_tobe_excl) != length(unique(as_date(sub$DatetimeBegin)))) {
    print(paste0("making kalman on ", s))
    na_idx_k <- is.na(sub$Concentration)
    if (na_idx_k[1] == T) {
      na_rm_init <- match(FALSE, na_idx_k)
      na_rm_init <- na_rm_init - 1
      str1 <- StructTS(sub$Concentration[-c(1:na_rm_init)],
                       type = "level",
                       fixed = c(NA, 0))
    } else{
      str1 <- StructTS(sub$Concentration,
                       type = "level",
                       fixed = c(NA, 0))
    }
    y_kalm <- KalmanSmooth(sub$Concentration, str1$model)
    summary(y_kalm$var)
    
    # sub$Concentration[na_idx_k] <- c(y_kalm[[1]])[na_idx_k]
    # sub$Concentration <- na_kalman(sub$Concentration)
    if (na_idx_k[1] == T) {
      a_1 <- sub$Concentration[na_rm_init + 1]
    } else{
      a_1 <- sub$Concentration[1]
    }
    sd_eps <- 0
    sd_eta <- as.numeric(sqrt(str1$coef[1]))
    kalman_start <- list(
      a_1 = a_1,
      P_1 = (sd_eps^2) + (sd_eta^2),
      sigma_eta = sd_eta,
      sigma_eps = sd_eps
    )
    my_y_kalm <- my_kalman_smoother(sub$Concentration, kalman_start = kalman_start)
    if (length(sub$Concentration) != length(my_y_kalm$state)) {
      stop("sub$concentrations and kalman smoother differ!")
    }
    sub$Concentration[na_idx_k] <- my_y_kalm$state[na_idx_k]
    sub$time <- as_date(sub$DatetimeBegin)
    my_y_kalm$variance[my_y_kalm$variance < 0] <- ceiling(my_y_kalm$variance[my_y_kalm$variance <
                                                                               0])
    return(list(sub = sub, Kdf = my_y_kalm)) #sub_list <- list(sub=sub,Kdf=my_y_kalm)
  } else {
    sub <- sub[-c(1:nrow(sub)), ]
    return(sub)
  }
}

daily_average <- function(sub_list, s, date_tobe_excl) {
  sub <- sub_list[[1]]
  EEA_daily <- sub %>%
    group_by(time) %>%
    summarise(
      min = min(Concentration),
      q1 = quantile(Concentration, probs = .25),
      mean = mean(Concentration),
      med = median(Concentration),
      q3 = quantile(Concentration, probs = .75),
      max = max(Concentration),
    )
  EEA_daily$AirQualityStation <- s
  EEA_daily <- EEA_daily[, c(8, 1:7)]
  names(EEA_daily)[-c(1, 2)] <-
    paste0(names(EEA_daily)[-c(1, 2)], "_", p)
  EEA_daily <- as.data.frame(EEA_daily)
  EEA_daily <- EEA_daily[!EEA_daily$time %in% date_tobe_excl, ]
  
  EEA_daily_uncertainty <- EEA_daily
  EEA_daily_uncertainty[!is.na(EEA_daily[, 3]), -c(1, 2)] <- 0
  names(EEA_daily_uncertainty)[-c(1, 2)] <- paste0("sd_", names(EEA_daily_uncertainty)[-c(1, 2)])
  Kdf <- sub_list$Kdf
  Kdf_t <- cbind(sub$time, Kdf)
  names(Kdf_t)[1] <- "time"
  for (d in unique(Kdf_t$time)) {
    #d <- unique(Kdf_t$time)[1] # d <- as.Date("2015-01-14") #d <- as.Date(17784)
    if (d %in% date_tobe_excl) {
      next
    } # d <- as.Date("2013-05-14") d <- as.Date("2023-11-25")
    sub_kdf <- subset(Kdf_t, time == d)
    pos_imp <- which(is.na(sub_kdf$data_y))
    if (length(pos_imp) == 0) {
      next
    }
    n_div <- (1 / 24)^2
    single_variance <- sum(sub_kdf$variance[pos_imp])
    Vt_mat <- matrix(0, 24, 24)
    for (i in pos_imp) {
      for (j in pos_imp) {
        if (j > i) {
          Vt_mat[i, j] <- sub_kdf$Pt_filter[i] * prod(sub_kdf$Lt[i:(j - 1)]) * (1 -
                                                                                  (sub_kdf$Nt[j - 1] * sub_kdf$Pt_filter[j]))
        }
      }
    }
    covariances <- 2 * sum(c(Vt_mat))
    mean_variance <- n_div * (single_variance + covariances)
    EEA_daily_uncertainty[EEA_daily_uncertainty$time == d, grep("mean", names(EEA_daily_uncertainty))] <- sqrt(mean_variance)
    
    if (min(sub_kdf$state[pos_imp]) < min(sub_kdf$data_y, na.rm = T)) {
      pos_min_imp <- which(sub_kdf$state == min(sub_kdf$state[pos_imp]))
      min_variance <- min(sub_kdf$variance[pos_min_imp])
    } else{
      min_variance <- 0
    }
    if (max(sub_kdf$state[pos_imp]) > max(sub_kdf$data_y, na.rm = T)) {
      pos_max_imp <- which(sub_kdf$state == max(sub_kdf$state[pos_imp]))
      max_variance <- min(sub_kdf$variance[pos_max_imp])
    } else{
      max_variance <- 0
    }
    print(d)
    EEA_daily_uncertainty[EEA_daily_uncertainty$time == d, grep("min", names(EEA_daily_uncertainty))] <- sqrt(min_variance)
    EEA_daily_uncertainty[EEA_daily_uncertainty$time == d, grep("max", names(EEA_daily_uncertainty))] <- sqrt(max_variance)
    
    x_full <- c(sub_kdf$data_y)
    x_full[pos_imp] <- sub_kdf$state[pos_imp]
    x_full <- cbind(x_full, 1:24)
    colnames(x_full) <- c("x", "i")
    x_ordered <- x_full[order(x_full[, 1]), ]
    n <- nrow(x_ordered)
    for (pq in c(0.25, .5, .75)) {
      m <- (1 - pq)
      j <- floor(n * pq + m)
      gamma <- n * pq + m - j
      var_j <- var_j1 <- cov_jj1 <- 0
      if (x_ordered[j, 2] %in% pos_imp) {
        var_j <- ((1 - gamma)^2) * sub_kdf$variance[x_ordered[j, 2]]
      }
      if (x_ordered[(j + 1), 2] %in% pos_imp) {
        var_j1 <- (gamma^2) * sub_kdf$variance[x_ordered[(j + 1), 2]]
      }
      if (x_ordered[j, 2] %in% pos_imp &
          x_ordered[(j + 1), 2] %in% pos_imp) {
        cov_jj1 <- gamma * (1 - gamma) * Vt_mat[x_ordered[j, 2], x_ordered[(j +
                                                                              1), 2]]
      }
      var_quantile <- sum(var_j, var_j1, cov_jj1)
      if (pq == .25) {
        var_q1 <- var_quantile
      }
      if (pq == .5) {
        var_med <- var_quantile
      }
      if (pq == .75) {
        var_q3 <- var_quantile
      }
    }
  }
  
  # n <- length(x)
  # m <- (1-p)
  # j <- floor(n*p + m)
  # gamma <- n*p + m - j
  # Q <- ((1-gamma)*x[j])+(gamma*x[j+1])
  
  return(list(EEA_daily = EEA_daily, EEA_daily_uncertainty = EEA_daily_uncertainty))
  # daily_list <- list(EEA_daily=EEA_daily,EEA_daily_uncertainty=EEA_daily_uncertainty)
}

my_kalman_filter <- function(data_y, kalman_start) {
  at <- Pt <- Pt_4smooth <- rep(NA, length(data_y))
  vt <- Ft <- Kt <- Kt_4smooth <- rep(NA, length(data_y))
  at[1] <- kalman_start$a_1
  Pt[1] <- Pt_4smooth[1] <- kalman_start$P_1
  sigma_eps <- kalman_start$sigma_eps
  sigma_eta <- kalman_start$sigma_eta
  n <- length(data_y)
  for (i in 1:n) {
    vt[i] <- data_y[i] - at[i]
    Ft[i] <- Pt[i] + (sigma_eps^2)
    Kt[i] <- Pt[i] / Ft[i]
    Kt_4smooth[i] <- Pt_4smooth[i] / (Pt_4smooth[i] + sigma_eps^2)
    if (i == n) {
      next
    }
    Pt_4smooth[i + 1] <- Pt_4smooth[i] * (1 - Kt_4smooth[i]) + (sigma_eta^2)
    if (is.na(data_y[i])) {
      Kt[i] <- 0
      at[i + 1] <- at[i]
      Pt[i + 1] <- Pt[i]  + sigma_eta^2
    } else{
      at[i + 1] <- at[i] + Kt[i] * vt[i]
      Pt[i + 1] <- Pt[i] * (1 - Kt[i]) + (sigma_eta^2)
    }
  }
  return(
    list(
      state = at,
      variance = Pt,
      Kalman_gain = Kt,
      var_innovations = Ft,
      innovations_hat = vt,
      data_y = data_y,
      Pt_4smooth = Pt_4smooth,
      Kt_4smooth = Kt_4smooth
    )
  )
}

my_kalman_smoother <- function(data_y, kalman_start) {
  filt <- my_kalman_filter(data_y, kalman_start = kalman_start)
  at <- filt[[1]]
  vt <- data_y - at
  Pt <- filt[[2]]
  Ft <- Pt + (kalman_start$sigma_eps^2)
  Kt <- filt[[3]]
  Lt <- 1 - Kt
  at_smooth <- rt <- rep(NA, length(data_y))
  Vt <- Nt <- rep(NA, length(data_y))
  rt[length(data_y)] <- 0
  Nt[length(data_y)] <- 0
  for (i in length(rt):2) {
    if (is.na(data_y[i])) {
      rt[i - 1] <- rt[i]
      Nt[i - 1] <-  ((Lt[i]^2) * Nt[i])
    } else{
      rt[i - 1] <- (vt[i] / (Ft[i])) + (Lt[i] * rt[i])
      Nt[i - 1] <- (1 / Ft[i]) + ((Lt[i]^2) * Nt[i])
    }
    at_smooth[i] <- at[i] + (Pt[i] * rt[i - 1])
    Vt[i] <- Pt[i] - ((Pt[i]^2) * Nt[i - 1])
  }
  at_smooth[1] <- at[1]
  Vt[1] <- Pt[1]
  return(
    data.frame(
      state = at_smooth,
      variance = Vt,
      Lt = Lt,
      Nt = Nt,
      Pt_filter = Pt,
      data_y = data_y
      # Kt = Kt,
      # Ft = Ft,
      # rt = rt,
      # at_filter =at,
      # vt = vt
    )
  )
}

EEA_files <-
  list.files(path = A24_path_1p1t_sub, pattern = ".rda")

EEA_short <- lapply(EEA_files, function(x) {
  nc <- nchar(x)
  substr(x, 1, nc - 4)
})
EEA_short <- unlist(EEA_short)
pol <-
  unique(sapply(EEA_short, function(x)
    substring(x, 1, nchar(x) - 5)))

for (p in pol) {
  print(paste("starting", p))
  EEA_pol <- EEA_files[grepl(paste0(p, "_"), EEA_files)]
  df_EEA <- foreach (EEA_y = EEA_pol, .combine = rbind) %dopar% {
    load(file.path(A24_path_1p1t_sub, EEA_y))
    print(paste("merged done for", p))
    df_EEA
  }
  stazz <- unique(df_EEA$AirQualityStation)
  foreach (s = stazz,
           # s = stazz[1] s = stazz[94] s = "STA.IT0861A"
           .packages = c("lubridate", "imputeTS")) %dopar% {
             print(paste(round((
               which(stazz == s) / length(stazz)
             ) * 100, 2), "%"))
             sub <- subset(df_EEA, AirQualityStation == s)
             sub <- sub[order(sub$DatetimeBegin), ]
             y <- substr(sub$DatetimeBegin, 1, 4)
             y <- unique(y)
             if (!all(sub$ID_AVGTIME %in% c(1, 2))) {
               print(paste(s, "of", p))
               stop("unknown temporal resolution")
             }
             # else if (length(unique(sub$ID_AVGTIME)) != 1 &&
             #          3 %in% unique(sub$ID_AVGTIME)) {
             #   print(paste("station", s, "of", p, "is mixed"))
             #   diviso <- mixed(sub, s)
             #   diviso_1_list <- daily(diviso[[1]], s)
             #   if (nrow(diviso[[2]]) > 2) {
             #     diviso_2_list <- hourly(diviso[[2]], s)
             #   } else{
             #     diviso_2 <- diviso[[2]][-c(1:nrow(diviso[[2]])), ]
             #   }
             #   EEA_daily <- rbind(diviso_1_list[[1]], diviso_2_list[[1]])
             #   EEA_daily_uncertainty <- rbind(diviso_1_list[[2]], diviso_2_list[[2]])
             # }
             else if (length(unique(sub$ID_AVGTIME)) == 1 &&
                      unique(sub$ID_AVGTIME) == 2) {
               print(paste("station", s, "of", p, "is all daily"))
               EEA_daily_list <- daily(sub, s)
               EEA_daily <- EEA_daily_list[[1]]
               EEA_daily_uncertainty <- EEA_daily_list[[2]]
             }
             else if (all(unique(sub$ID_AVGTIME) %in% c(1))) {
               print(paste("station", s, "of", p, "is all hourly/bi-hourly"))
               EEA_daily_list <- hourly(sub, s) #EEA_daily_list <- daily_list
               if (class(EEA_daily_list) == "list") {
                 EEA_daily <- EEA_daily_list[[1]]
                 EEA_daily_uncertainty <- EEA_daily_list[[2]]
               }
             }
             else {
               stop(paste(s, "in", p, "non ricade in nessun ambito"))
             }
             if (class(EEA_daily_list) == "list") {
               save(EEA_daily, file = file.path(A31_path_1p1s, paste0(p, "_", s, ".rda")))
               save(EEA_daily_uncertainty, file = file.path(A31_path_1p1s, paste0(p, "_", s, "_uncertainty.rda")))
             }
             rm(EEA_daily, EEA_daily_uncertainty, EEA_daily_list)
           }
}

### A.3.2. merging (commented API) ####
cat("Start A.3.2 - merging daily data")

A31_files <- list.files(A31_path_1p1s, pattern = ".rda")
A31_files_unc <- A31_files[grep("uncertainty", A31_files)]
A31_files_val <- setdiff(A31_files, A31_files_unc)

#values
load(file.path(A31_path_1p1s, A31_files_val[1]))
AirQualityStation <- unique(EEA_daily$AirQualityStation)
for (A31_fv in A31_files_val[-1]) {
  load(file.path(A31_path_1p1s, A31_fv))
  AirQualityStation <- unique(c(AirQualityStation, unique(EEA_daily$AirQualityStation)))
}


# 25-01-2026
# abbiamo AirQualityStation che sono le stazioni del dataset nuovo (15gg)
# quindi ora scarichiamo il metadata da amelia :
# da decommentare
# table_name <- "aqclim_station_registry_information"
# first <- get_page(0,table_name)
#
# total_elements <- first$pagination$totalElements
# page_size <- first$pagination$pageSize
# total_pages <- ceiling(total_elements / page_size)
# metadataEEA <- first$data
# if (total_pages > 1) {
#   for (p in 2:total_pages) {
#     cat("Scarico pagina metadata EEA", p, "di", total_pages, "\n")
#
#     page <- get_page(p-1,table_name)
#     metadataEEA <- rbind(metadataEEA, page$data)
#   }
# }
#
# invece noi carichiamo da scarichiamo da Zenodo
download.file(
  "https://zenodo.org/records/17605148/files/Station_registry_information.CSV?download=1",
  destfile = file.path(A32_path_merge, "Station_registry_information.CSV")
)

metadataEEA <- read_csv(file.path(A32_path_merge, "Station_registry_information.CSV"))
metadataEEA$AirQualityStation
new_stations <- setdiff(AirQualityStation, metadataEEA$AirQualityStation)

if (length(new_stations) > 0) {
  options(timeout = 1000)
  download.file(
    "https://discomap.eea.europa.eu/map/fme/metadata/PanEuropean_metadata.csv",
    destfile = file.path(A32_path_merge, "raw_metadata.csv")
  )
  
  PanEuropean_metadata <-
    read_delim(
      file.path(A32_path_merge, "raw_metadata.csv"),
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
  raw_metadataEEA <- unique(PanEuropean_metadata[, c(
    "Countrycode",
    "AirQualityStation",
    "AirPollutantCode",
    "ObservationDateBegin",
    "ObservationDateEnd",
    "Projection",
    "Longitude",
    "Latitude",
    "Altitude",
    "MeasurementType",
    "AirQualityStationType",
    "AirQualityStationArea"
  )])
  rm(PanEuropean_metadata)
  raw_metadataEEA <- raw_metadataEEA[raw_metadataEEA$Countrycode == "IT", ]
  raw_metadataEEA <- unique(raw_metadataEEA[, c(
    "AirQualityStation",
    "Longitude",
    "Latitude",
    "Altitude",
    "AirQualityStationType",
    "AirQualityStationArea"
  )])
  metadataEEA_newstaz <- raw_metadataEEA[raw_metadataEEA$AirQualityStation %in% new_stations, ]
  rm(raw_metadataEEA)
  
  # check spatial buffer
  for (i in 1:nrow(metadataEEA_newstaz)) {
    same_staz <- which(metadataEEA_newstaz$Longitude[i] < metadataEEA$Longitude + 0.005 &
      metadataEEA_newstaz$Longitude[i] > metadataEEA$Longitude - 0.005 &
      metadataEEA_newstaz$Latitude[i] < metadataEEA$Latitude + 0.005 &
      metadataEEA_newstaz$Latitude[i] > metadataEEA$Latitude - 0.005)
    if(length(same_staz)!=0){
      print(
        paste0("new station called:",
          metadataEEA_newstaz$AirQualityStation[i],
          "old station called",
          metadataEEA$AirQualityStation[same_staz]))
      stop("different stations too close")}
  }
  
  coordinates(metadataEEA_newstaz) <- c("Longitude", "Latitude")
  crs_wgs84 <- CRS(SRS_string = "EPSG:4326")
  slot(metadataEEA_newstaz, "proj4string") <- crs_wgs84
  
  # import IT_adm_bouondaries
  download.file(
    "https://www.istat.it/storage/cartografia/confini_amministrativi/generalizzati/2025/Limiti01012025_g.zip",
    destfile = file.path(A32_path_merge, "IT_adm_lim.zip")
  )
  A32sub_path_it_adm <- file.path(A32_path_merge, "IT_adm_lim")
  dir.create(A32sub_path_it_adm)
  unzip(file.path(A32_path_merge, "IT_adm_lim.zip"), exdir = A32sub_path_it_adm)
  shp_folder <- file.path(A32sub_path_it_adm, list.files(A32sub_path_it_adm)[grep("Com", list.files(A32sub_path_it_adm))])
  shp_file <- gsub("\\.shp", "", list.files(shp_folder)[grep(".shp", list.files(shp_folder))])
  
  comuni <- st_read(dsn = shp_folder, layer = shp_file)
  
  metadataEEA_newstaz <- cbind(
    metadataEEA_newstaz@data,
    metadataEEA_newstaz@coords,
    over(metadataEEA_newstaz, as_Spatial(st_transform(
      comuni, st_crs(4326)
    )))
  )
  metadataEEA_newstaz <- metadataEEA_newstaz[, c(
    "AirQualityStation",
    "Longitude",
    "Latitude",
    "Altitude",
    "AirQualityStationType",
    "AirQualityStationArea",
    "COD_RIP",
    "COD_REG",
    "COD_PROV",
    "COD_CM",
    "COD_UTS",
    "PRO_COM",
    "PRO_COM_T",
    "COMUNE",
    "Shape_Area"
  )]
  names(metadataEEA_newstaz)[15] <- "Area comune"
  
  metadataEEA <- rbind(metadataEEA, metadataEEA_newstaz)
  
}# ok ho aggiunto due stazioni per il periodo 2000-2012

write.table(
  metadataEEA,
  file.path(A32_path_merge, "AQCLIM_Station_registry_information.csv"),
  row.names = F,
  col.names = names(metadataEEA),
  quote = F,
  sep = ",",
  dec = "."
)

# export to AMELIA ! (update the old one!)
# che però non è da esportare l'intero csv ma bensì
# aggiungere le righe nuove a quello già presente
EEA_meta <- unique(metadataEEA[, c("AirQualityStation", "Longitude", "Latitude")])
EEA_meta <- EEA_meta[EEA_meta$AirQualityStation %in% AirQualityStation,]
time <- seq.Date(as.Date("2000-01-01"), as.Date("2012-12-31"), by = "days")
EEA_meta <- data.frame(cbind(EEA_meta, rep(time, each = nrow(EEA_meta))))
names(EEA_meta)[4] <- c("time")

EEA_pol <- lapply(A31_files_val, function(x) {
  nc <- nchar(x)
  substr(x, 1, nc - 16)
})
EEA_pol <- unique(unlist(EEA_pol))

for (p in EEA_pol) {
  A31_files_val_p <- A31_files_val[grep(paste0(p, "_"), A31_files_val)]
  EEA_daily <-
    foreach (i = A31_files_val_p, .combine = rbind) %dopar% {
      load(file.path(A31_path_1p1s, i))
      EEA_daily
    }
  # save(EEA_daily,file=paste0("data/AQ/EEA/daily/T/",p,".Rdata"))
  if (p == EEA_pol[1]) {
    EEA_all_daily <- merge(EEA_meta, EEA_daily, all.x = T)
  } else{
    EEA_all_daily <- merge(EEA_all_daily, EEA_daily, all.x = T)
  }
  print(paste(p, "completed"))
}
AQ_EEA_v300_df <- EEA_all_daily
# drop days without any measurements
AQ_EEA_v300_df <- AQ_EEA_v300_df[!is.na(AQ_EEA_v300_df$mean_CO) |
                                         !is.na(AQ_EEA_v300_df$mean_NO2) |
                                         !is.na(AQ_EEA_v300_df$mean_NO) |
                                         !is.na(AQ_EEA_v300_df$mean_O3) |
                                         !is.na(AQ_EEA_v300_df$mean_PM10) |
                                         !is.na(AQ_EEA_v300_df$mean_PM2.5) |
                                         !is.na(AQ_EEA_v300_df$mean_SO2),]

AQ_EEA_v300_df <- AQ_EEA_v300_df[order(AQ_EEA_v300_df$time,
                                       AQ_EEA_v300_df$Latitude,
                                       AQ_EEA_v300_df$Longitude), ]

save(AQ_EEA_v300_df, file = file.path(A32_path_merge, "AQ_EEA_v300_df.rda"))

