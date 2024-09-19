# 2. Preprocessing ####

#This script take csv files downloaded and conver it in R dataframe
#Every output is one station, one pollutant, one year

library(doParallel)
library(foreach)
library(httr)
registerDoParallel(cores = detectCores())
library(lubridate)

## 2.1 Identify problematic station ####
print("starting 2.1 Identify problematic station")
rm(list = ls())
gc()
source("script/preprocessing/classify_problematic_rawfiles.R")

## 2.2 Fixing stations (csv to Rdata) ####

#ok stations
print("starting 2.2 Lighter files from csv to Rdata")

rm(list = ls())
gc()
EEAfiles <-
  list.files(path = "data/raw",
             pattern = ".csv")
load("data/preprocessing/removing_files.Rdata")
load("data/preprocessing/complementary_files.Rdata")
load("data/preprocessing/duplicated_rawfiles.Rdata")

EEAfiles <- EEAfiles[which(!EEAfiles %in% removing_files)]
EEAfiles <- EEAfiles[which(!EEAfiles %in% duplicated_dates)]
EEAfiles <-
  EEAfiles[which(!EEAfiles %in% unlist(complementary_files))]

start_time <- Sys.time()
foreach (i = EEAfiles) %dopar% {
  source("script/functions.R")
  df_EEA <- open_raw(i, "data/raw")
  save(
    #require uniqueness if not overwrite
    df_EEA,
    file = paste0(
      "data/preprocessing/1s_1p_1y/",
      unique(df_EEA$AirQualityStation),
      "_",
      unique(df_EEA$AirPollutant),
      "_",
      unique(substr(df_EEA$DatetimeBegin, 1, 4))
      ,
      ".Rdata"
    )
  )
  rm(exampleEEA)
}

#problematic stations (duplicated dates)
rm(list = ls())
gc()
EEAfiles <-
  list.files(path = "data/raw",
             pattern = ".csv")
load("data/preprocessing/removing_files.Rdata")
load("data/preprocessing/complementary_files.Rdata")
load("data/preprocessing/duplicated_rawfiles.Rdata")
EEAfiles <- duplicated_dates
EEAfiles <- EEAfiles[!EEAfiles %in% unlist(complementary_files)]

foreach (i = EEAfiles) %dopar% {
  source("script/functions.R")
  df_EEA <- open_raw(i, "data/raw")
  df_EEA <- duplicated_dates_correction(df_EEA)
  save(
    #require uniqueness if not overwrite
    df_EEA,
    file = paste0(
      "data/preprocessing/1s_1p_1y/",
      unique(df_EEA$AirQualityStation),
      "_",
      unique(df_EEA$AirPollutant),
      "_",
      unique(substr(df_EEA$DatetimeBegin, 1, 4))
      ,
      ".Rdata"
    )
  )
  rm(exampleEEA)
}

#problematic stations (complemetary files)
rm(list = ls())
gc()
EEAfiles <-
  list.files(path = "data/raw",
             pattern = ".csv")
load("data/preprocessing/removing_files.Rdata")
load("data/preprocessing/complementary_files.Rdata")
load("data/preprocessing/duplicated_rawfiles.Rdata")

foreach (i = 1:length(complementary_files)) %dopar% {
  source("script/functions.R")
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
  df_EEA1 <- open_raw(file1, "data/raw")
  if (file1 %in% duplicated_dates) {
    df_EEA1 <- duplicated_dates_correction(df_EEA1)
    df_EEA1 <- df_EEA1[,-which(names(df_EEA1)=="date")]
  }
  df_EEA2 <- open_raw(file2, "data/raw")
  if (file2 %in% duplicated_dates) {
    df_EEA2 <- duplicated_dates_correction(df_EEA2)
    df_EEA2 <- df_EEA2[,-which(names(df_EEA2)=="date")]
  }
  if (!overlap) {
    df_EEA <- rbind(df_EEA1, df_EEA2)
  } else if (same_res) {
    overlap_time <- intersect(df_EEA1$DatetimeBegin,
                              df_EEA2$DatetimeBegin)
    df_EEA1 <-
      df_EEA1[!df_EEA1$DatetimeBegin %in% overlap_time,]
    df_EEA <- rbind(df_EEA1, df_EEA2)
  } else {
    overlap_time <- intersect(df_EEA1$DatetimeBegin,
                              df_EEA2$DatetimeBegin)
    res <- c("hour", "var", "day")
    for (d in overlap_time) {
      nres1 <-
        which(res == df_EEA1$AveragingTime[df_EEA1$DatetimeBegin == d])
      nres2 <-
        which(res == df_EEA2$AveragingTime[df_EEA2$DatetimeBegin == d])
      if (nres1 <= nres2) {
        df_EEA2 <- df_EEA2[!df_EEA2$DatetimeBegin == d,]
      } else {
        df_EEA1 <- df_EEA1[!df_EEA1$DatetimeBegin == d,]
      }
    }
    overlap_time <- intersect(as_date(df_EEA1$DatetimeBegin),
                              as_date(df_EEA2$DatetimeBegin))
    for (d in overlap_time) {
      res1 <- unique(df_EEA1$AveragingTime[as_date(df_EEA1$DatetimeBegin) == d])
      if (all(res1 %in% c("hour","var"))) {res1<-res1[1]}
      nres1 <-
        which(res == res1)
      res2 <- unique(df_EEA2$AveragingTime[as_date(df_EEA2$DatetimeBegin) == d])
      if (all(res2 %in% c("hour","var"))) {res2<-res2[1]}
      nres2 <-
        which(res == res2)
      if (nres1 <= nres2) {
        df_EEA2 <- df_EEA2[as_date(df_EEA2$DatetimeBegin) != d,]
      } else {
        df_EEA1 <- df_EEA1[as_date(df_EEA1$DatetimeBegin) != d,]
      }
    }
    df_EEA <- rbind(df_EEA1, df_EEA2)
  }
  save(
    #require uniqueness if not overwrite
    df_EEA,
    file = paste0(
      "data/preprocessing/1s_1p_1y/",
      unique(df_EEA$AirQualityStation),
      "_",
      unique(df_EEA$AirPollutant),
      "_",
      unique(substr(df_EEA$DatetimeBegin, 1, 4))
      ,
      ".Rdata"
    )
  )
  rm(df_EEA, df_EEA1, df_EEA2)
}


## 2.3 Bind all stations into same year and pollutant ####
print("2.3 Bind all stations into same year and pollutant")

rm(list = ls())
gc()

EEAfiles <-
  list.files(path = "data/preprocessing/1s_1p_1y", pattern = ".Rdata")

for (i in EEAfiles) {
  print(which(EEAfiles == i))
  load(paste0("data/preprocessing/1s_1p_1y/", i))
  pol <- unique(df_EEA$AirPollutant)
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
}

df_POL_inf <- data.frame(
  ID_POL = c(10, 38, 8, 5, 1, 7, 6001, 35),
  POL = c("CO", "NO", "NO2", "PM10", "SO2", "O3", "PM2.5", "NH3")
)
df_POL <- merge(as.data.frame(POL), df_POL_inf, all.x = T)
names(df_POL)[1] <- "AirPollutant"

df_AVGTIME <- data.frame(ID_AVGTIME = c(1:length(AVG_TIME)),
                         AveragingTime = AVG_TIME)

df_POL$ID_list <- 1:nrow(df_POL)
EEARfiles <-
  list.files(path = "data/preprocessing/1s_1p_1y",
             pattern = ".Rdata")
EEARfiles_p <- list()
for (p in df_POL$AirPollutant) {
  EEARfiles_p[[df_POL$ID_list[df_POL$AirPollutant == p]]] <-
    EEARfiles[grep(paste0(p, "_"), EEARfiles)]
}
sum(sapply(EEARfiles_p, length))
# #WATCH OUT FOR NAME CONTAINED IN OTHER NAME e.g. NO and NO2, they have to be fixed manually
# NO_id <- df_POL$ID_list[df_POL$AirPollutant=="NO"]
# EEARfiles_p[[NO_id]] <- EEARfiles_p[[NO_id]][-grep("NO2", EEARfiles_p[[NO_id]])]
# sum(sapply(EEARfiles_p, length)) #OK
length(EEARfiles)

for (i in 1:length(EEARfiles_p)) { 
  print(paste("Pollutant", df_POL$AirPollutant[i]))
  EEARfiles_pi <- EEARfiles_p[[i]]
  for (y in 2013:2023) {
    print(paste("Start: Year", (y)))
    EEARfiles_p_y <-
      EEARfiles_pi[grep(paste0(y, ".Rdata"), EEARfiles_pi)]
    if (length(EEARfiles_p_y) > 0) {
      df_EEA <-
        foreach (j = EEARfiles_p_y, .combine = rbind) %dopar% {
          load(paste0("data/preprocessing/1s_1p_1y/", j))
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
      save(
        df_EEA,
        file = paste0(
          "data/preprocessing/1p_1y/",
          df_POL$AirPollutant[i],
          "_",
          y,
          ".Rdata"
        )
      )
      rm(df_EEA)
      gc()
    }
  }
}


## 2.4 Summary analysis of the data ####

print("2.4 Summary analysis of the data")
rm(list = ls())
gc()

EEA_files <- list.files(path = "data/preprocessing/1p_1y",
                        pattern = ".Rdata")
EEA_POL <- c()
for (i in 1:length(EEA_files)) {
  nc <- nchar(EEA_files[i])
  EEA_POL[i] <- substr(EEA_files[i],
                       1,
                       nc - 11)
}
EEA_POL <- unique(EEA_POL)

for (p in EEA_POL) {
  EEA_files_p <- EEA_files[grep(paste0(p, "_"), EEA_files)]
  df_EEA <- foreach (i = EEA_files_p, .combine = rbind) %dopar% {
    load(paste0("data/preprocessing/1p_1y/", i))
    df_EEA
  }
  n <- nrow(df_EEA)
  summary_df <- data.frame(
    pol = p,
    n_obs = n,
    n_staz = length(unique(df_EEA$AirQualityStation)),
    Concentration_NA = sum(is.na(df_EEA$Concentration) /
                             n * 100),
    validity_NA = sum(is.na(df_EEA$Validity)) / n *
      100,
    validity_neg99 = sum(df_EEA$Validity == -99, na.rm = T) /
      n * 100,
    validity_neg1 = sum(df_EEA$Validity == -1, na.rm = T) /
      n * 100,
    validity_1 = sum(df_EEA$Validity == 1, na.rm = T) /
      n * 100,
    validity_2 = sum(df_EEA$Validity == 2, na.rm = T) /
      n * 100,
    validity_3 = sum(df_EEA$Validity == 3, na.rm = T) /
      n * 100,
    verification_NA = sum(is.na(df_EEA$Verification)) /
      n * 100,
    verification_1 = sum(df_EEA$Verification == 1, na.rm = T) /
      n * 100,
    verification_2 = sum(df_EEA$Verification == 2, na.rm = T) /
      n * 100,
    verification_3 = sum(df_EEA$Verification == 3, na.rm = T) /
      n * 100,
    time_1h = sum(df_EEA$ID_AVGTIME == 1, na.rm = T) /
      n * 100,
    time_2h = sum(df_EEA$ID_AVGTIME == 2, na.rm = T) /
      n * 100,
    time_24h = sum(df_EEA$ID_AVGTIME == 3, na.rm = T) /
      n * 100,
    Datetime_NA = sum(is.na(df_EEA$DatetimeBegin)) /
      n * 100,
    Datetime_start = min(as.Date(df_EEA$DatetimeBegin), na.rm = T),
    Datetime_end = max(as.Date(df_EEA$DatetimeBegin), na.rm = T),
    years_covered = paste(unique(substr(
      as.Date(df_EEA$DatetimeBegin), 1, 4
    )), collapse = "/")
  )
  if (p == EEA_POL[1]) {
    summary_EEA_df <- summary_df
  } else{
    summary_EEA_df <- rbind(summary_EEA_df, summary_df)
  }
  print(paste(p, "finished"))
}
row.names(summary_EEA_df) <- summary_EEA_df$pol
summary_EEA_df <- summary_EEA_df[,-1]
summary_EEA_df_1 <- summary_EEA_df[, c(1:3)]
write.table(
  format(summary_EEA_df_1, scientific = T, digits = 2),
  file = "data/preprocessing/summary/overview.csv",
  sep = ",",
  col.names = NA,
  row.names = T
)

summary_EEA_df_2 <- summary_EEA_df[, c(4:9)]
write.table(
  format(summary_EEA_df_2, scientific = T, digits = 2),
  file = "data/preprocessing/summary/validity.csv",
  sep = ",",
  col.names = NA,
  row.names = T
)

summary_EEA_df_3 <- summary_EEA_df[, c(10:13)]
write.table(
  format(summary_EEA_df_3, scientific = T, digits = 2),
  file = "data/preprocessing/summary/verification.csv",
  sep = ",",
  col.names = NA,
  row.names = T
)

summary_EEA_df_4 <- summary_EEA_df[, c(14:16)]
write.table(
  format(summary_EEA_df_4, scientific = T, digits = 2),
  file = "data/preprocessing/summary/timeres.csv",
  sep = ",",
  col.names = NA,
  row.names = T
)

summary_EEA_df_5 <- summary_EEA_df[, c(17:20)]
write.table(
  format(summary_EEA_df_5, scientific = T, digits = 2),
  file = "data/preprocessing/summary/period.csv",
  sep = ",",
  col.names = NA,
  row.names = T
)

summary_EEA_df <- as.data.frame(t(summary_EEA_df))
names(summary_EEA_df) <- summary_EEA_df[1,]
summary_EEA_df <- summary_EEA_df[-1,]
summary_EEA_df
write.csv(summary_EEA_df, file = "data/preprocessing/summary_EEA_df.csv")

## 2.5 Anomalies detection ####
print("starting 2.5 Anomalies detection")

rm(list = ls())
gc()

EEA_files <-
  list.files("data/preprocessing/1p_1y", pattern = ".Rdata")
EEA_short <- lapply(EEA_files, function(x) {
  substr(x, 1, nchar(x) - 6)
})
pol <-
  unique(sapply(EEA_short, function(x)
    substr(x, 1, nchar(x) - 5)))
EEA_short <- unlist(EEA_short)

# table 1: verification flag
all_df <- foreach(p = pol, .combine = rbind) %dopar% {
  #1. tutto il periodo per ogni inquinante
  EEA_pol <- EEA_files[grepl(paste0(p, "_"), EEA_files)]
  for (pol_i in EEA_pol) {
    load(paste0("data/preprocessing/1p_1y/", pol_i))
    if (pol_i == EEA_pol[1]) {
      df_EEA_t <- df_EEA
    } else{
      df_EEA_t <- rbind(df_EEA_t, df_EEA)
    }
  }
  df_EEA <- df_EEA_t
  rm(df_EEA_t)
  #2. validity filtering
  df_EEA_withNA <- df_EEA
  df_EEA <-
    df_EEA[df_EEA$Validity %in% c(1, 2, 3),] #tolti tutti i NA
  df_EEA <- df_EEA[df_EEA$Concentration > 0,] #tolti tutti i NA
  n_NA <- 1 - (nrow(df_EEA) / nrow(df_EEA_withNA))
  #3. rimozione outlier
  #3a. analisis flag verification
  n <- 1
  s <- summary(df_EEA$Concentration)
  sd <- sqrt(var(df_EEA$Concentration, na.rm = T))
  df <- t(as.data.frame(rbind(n, n_NA, as.matrix(round(
    s, 3
  )), sd)))
  row.names(df) <- p
  all_df <- df
  df <- foreach(v = 1:3, .combine = rbind) %dopar% {
    n <- nrow(df_EEA[df_EEA$Verification == v,]) / nrow(df_EEA)
    n_NA <-
      1 - (nrow(df_EEA[df_EEA$Verification == v,]) / nrow(df_EEA_withNA[df_EEA_withNA$Verification ==
                                                                          v,]))
    s <- summary(df_EEA$Concentration[df_EEA$Verification == v])
    sd <-
      sqrt(var(df_EEA$Concentration[df_EEA$Verification == v], na.rm = T))
    df <- t(as.data.frame(rbind(n, n_NA, as.matrix(round(
      s, 3
    )), sd)))
    row.names(df) <- paste0(p, "_", v)
    df
  }
  all_df <- rbind(all_df, df)
  all_df
}
write.table(
  format(all_df, scientific = T, digits = 2),
  file = "data/preprocessing/anomalies/summary_verification.csv",
  sep = ",",
  col.names = NA
)

# table 2: using sigma
all_df <- foreach(p = pol, .combine = rbind) %dopar% {
  #.combine=cbind
  #1. tutto il periodo per ogni inquinante
  EEA_pol <- EEA_files[grepl(paste0(p, "_"), EEA_files)]
  for (pol_i in EEA_pol) {
    load(paste0("data/preprocessing/1p_1y/", pol_i))
    if (pol_i == EEA_pol[1]) {
      df_EEA_t <- df_EEA
    } else{
      df_EEA_t <- rbind(df_EEA_t, df_EEA)
    }
  }
  df_EEA <- df_EEA_t
  rm(df_EEA_t)
  df_EEA <-
    df_EEA[df_EEA$Validity %in% c(1, 2, 3),] #tolti tutti i NA
  df_EEA <- df_EEA[df_EEA$Concentration > 0,] #tolti tutti i NA
  #3. rimozione outlier
  #3a. sd analysis
  df_EEA$Concentration2 <- df_EEA$Concentration
  df_EEA$Concentration2[df_EEA$Concentration2 <= 1] <- 1
  df_EEA$Concentration_log <-
    log(df_EEA$Concentration2) #tolti tutti i NA
  sd <- 1
  n <- nrow(df_EEA)
  mu <- mean(df_EEA$Concentration, na.rm = T)
  sigma <- sd * sqrt(var(df_EEA$Concentration, na.rm = T))
  out <- sum(df_EEA$Concentration > (mu + sigma), na.rm = T) / n
  df <- as.data.frame(cbind(sigma, out))
  row.names(df) <- p
  names(df) <- c("sd", paste0("out_", sd, "sd"))
  mul <- mean(df_EEA$Concentration_log, na.rm = T)
  sigmal <- sd * sqrt(var(df_EEA$Concentration_log, na.rm = T))
  outl <-
    sum(df_EEA$Concentration_log > (mul + sigmal), na.rm = T) / n
  dfl <- as.data.frame(cbind(sigmal, outl))
  row.names(dfl) <- paste0("log(", p, ")")
  names(dfl) <- c("sd", paste0("out_", sd, "sd"))
  df <- rbind(df, dfl)
  all_df <- df
  for (sd in 2:6) {
    sigma <- sd * sqrt(var(df_EEA$Concentration, na.rm = T))
    out <- sum(df_EEA$Concentration > (mu + sigma), na.rm = T) / n
    df <- as.data.frame(out)
    names(df) <- paste0("out_", sd, "sd")
    sigmal <- sd * sqrt(var(df_EEA$Concentration_log, na.rm = T))
    outl <-
      sum(df_EEA$Concentration_log > (mul + sigmal), na.rm = T) / n
    dfl <- as.data.frame(outl)
    names(dfl) <- c(paste0("out_", sd, "sd"))
    df <- rbind(df, dfl)
    all_df <- cbind(all_df, df)
  }
  all_df
}
name_file <- "data/preprocessing/anomalies/sigma.csv"
write.table(
  format(all_df, digits = 2, scientific = T),
  file = name_file,
  sep = ",",
  col.names = NA
)

# part 3: histograms
foreach(p = pol) %dopar% {
  #.combine=cbind
  #1. tutto il periodo per ogni inquinante
  EEA_pol <- EEA_files[grepl(paste0(p, "_"), EEA_files)]
  for (pol_i in EEA_pol) {
    load(paste0("data/preprocessing/1p_1y/", pol_i))
    if (pol_i == EEA_pol[1]) {
      df_EEA_t <- df_EEA
    } else{
      df_EEA_t <- rbind(df_EEA_t, df_EEA)
    }
  }
  df_EEA <- df_EEA_t
  rm(df_EEA_t)
  df_EEA <-
    df_EEA[df_EEA$Validity %in% c(1, 2, 3),] #tolti tutti i NA
  df_EEA <- df_EEA[df_EEA$Concentration > 0,] #tolti tutti i NA
  #3. rimozione outlier
  #3a. sd analysis
  df_EEA$Concentration2 <- df_EEA$Concentration
  df_EEA$Concentration2[df_EEA$Concentration2 <= 1] <- 1
  df_EEA$Concentration_log <-
    log(df_EEA$Concentration2) #tolti tutti i NA
  name_file <-
    paste0("plot/preprocessing/anomalies/hist", p, ".png")
  png(name_file)
  hist(df_EEA$Concentration, main = p, breaks = 50)
  dev.off()
  name_file <-
    paste0("plot/preprocessing/anomalies/hist", p, "_log.png")
  png(name_file)
  hist(df_EEA$Concentration_log,
       main = p,
       breaks = 50)
  dev.off()
}

#part 4: fix thresholds
fix_thr <-
  foreach(p = pol, .combine = rbind) %dopar% {
    #.combine=cbind
    #1. tutto il periodo per ogni inquinante
    print(paste("starting", p))
    EEA_pol <- EEA_files[grepl(paste0(p, "_"), EEA_files)]
    for (pol_i in EEA_pol) {
      load(paste0("data/preprocessing/1p_1y/", pol_i))
      if (pol_i == EEA_pol[1]) {
        df_EEA_t <- df_EEA
      } else{
        df_EEA_t <- rbind(df_EEA_t, df_EEA)
      }
    }
    df_EEA <- df_EEA_t
    rm(df_EEA_t)
    df_EEA <-
      df_EEA[df_EEA$Validity %in% c(1, 2, 3),] #tolti tutti i NA
    df_EEA <- df_EEA[df_EEA$Concentration > 0,] #tolti tutti i NA
    #3. rimozione outlier
    #3a. sd analysis
    df_EEA$Concentration2 <- df_EEA$Concentration
    df_EEA$Concentration2[df_EEA$Concentration2 <= 1] <- 1
    df_EEA$Concentration_log <-
      log(df_EEA$Concentration2) #tolti tutti i NA
    pol_all <- df_EEA$Concentration
    pol_all <- pol_all[order(pol_all)]
    fix_thr2 <-
      data.frame(avg = mean(pol_all), sd = sqrt(var(pol_all)))
    names(fix_thr2) <- paste0(names(fix_thr2), "_all")
    for (perc in c(.99, .999, .9999, .99999)) {
      thr <- perc * length(pol_all)
      thr <- round(thr, 0)
      pol_thr <- pol_all[thr]
      pol_cut <- pol_all[pol_all < pol_thr]
      n_out <- length(pol_all) - length(pol_cut)
      staz <-
        unique(df_EEA$AirQualityStation[df_EEA$Concentration >= pol_thr])
      subset_df <- df_EEA[df_EEA$Concentration >= pol_thr, ]
      df <- data.frame(
        thr = pol_thr,
        out = n_out,
        n = length(staz),
        avg = mean(pol_cut),
        sd = sqrt(var(pol_cut))
      )
      names(df) <- paste0(names(df), "_",
                          which(c(.99, .999, .9999, .99999) == perc))
      if (perc == .99) {
        fix_thr <- cbind(fix_thr2, df)
      } else {
        fix_thr <- cbind(fix_thr, df)
      }
    }
    print(paste(p, "ended"))
    fix_thr
  }
write.table(
  format(as.data.frame(t(fix_thr)), scientific = T, digits = 2),
  file = "data/preprocessing/anomalies/fix_thr.csv",
  col.names = NA,
  sep = ","
)

#part 5: histograms out
library(ggplot2)
foreach(p = pol, .combine = rbind) %dopar% {
  #.combine=cbind
  #1. tutto il periodo per ogni inquinante
  EEA_pol <- EEA_files[grepl(paste0(p, "_"), EEA_files)]
  for (pol_i in EEA_pol) {
    load(paste0("data/preprocessing/1p_1y/", pol_i))
    if (pol_i == EEA_pol[1]) {
      df_EEA_t <- df_EEA
    } else{
      df_EEA_t <- rbind(df_EEA_t, df_EEA)
    }
  }
  df_EEA <- df_EEA_t
  rm(df_EEA_t)
  df_EEA <-
    df_EEA[df_EEA$Validity %in% c(1, 2, 3),] #tolti tutti i NA
  df_EEA <- df_EEA[df_EEA$Concentration > 0,] #tolti tutti i NA
  pol_all <- df_EEA$Concentration
  pol_all <- pol_all[order(pol_all)]
  print(p)
  for (perc in c(.99, .999, .9999, .99999)) {
    thr <- perc * length(pol_all)
    thr <- round(thr, 0)
    pol_thr <- pol_all[thr]
    pol_cut <- pol_all[pol_all >= pol_thr]
    iter <- which(c(.99, .999, .9999, .99999) == perc)
    name_file <-
      paste0("plot/preprocessing/anomalies/hist_",
             p,
             "_fix_",
             iter,
             "_thr.png")
    png(name_file,width = 400, height = 480)
    print(
      ggplot(data = df_EEA[df_EEA$Concentration > pol_thr, ]) +
        geom_histogram(aes(
          x = Concentration, fill = as.factor(AirQualityStation)
        ),
        col = "black") +
        theme(legend.position = "none") +
        scale_x_continuous(breaks = 10 ^ c(1:10), trans = "pseudo_log") +
        scale_y_continuous(breaks = 10 ^ c(1:20), trans = "pseudo_log") +
        ggtitle(label = p)
    )
    dev.off()
  }
}

#part 6: subsetting
EEA_files <-
  list.files("data/preprocessing/1p_1y", pattern = ".Rdata")
EEA_short <- lapply(EEA_files, function(x) {
  nc <- nchar(x)
  substr(x, 1, nc - 6)
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
write.csv(pol_thr, file = "data/preprocessing/anomalies/selected_thresholds.csv")

foreach(p = pol) %dopar% { 
  EEA_pol <- EEA_files[grepl(paste0(p, "_"), EEA_files)]
  thr <- pol_thr$upp_b[pol_thr$pol == p]
  for (EEA_y in EEA_pol) {
    print(EEA_y)
    load(paste0("data/preprocessing/1p_1y/", EEA_y))
    df_EEA <-
      df_EEA[df_EEA$Validity %in% c(1, 2, 3), ] #tolti tutti i NA
    df_EEA <- df_EEA[df_EEA$Concentration > 0, ] #tolti tutti i NA
    df_EEA <- df_EEA[df_EEA$Concentration < thr, ]
    save(df_EEA,
         file = paste0("data/preprocessing/1p_1y_subsetted/", EEA_y))
  }
}
