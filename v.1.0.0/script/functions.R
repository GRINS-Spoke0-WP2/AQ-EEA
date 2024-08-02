#EEA_preprocessing ####
open_raw <- function(i, path) {
  exampleEEA <- read.csv(paste0(path, "/", i))
  if (class(exampleEEA) != "data.frame") {
    stop(paste("the CSV file", i, "is not a dataframe"))
  }
  if (nrow(exampleEEA) == 0) {
    stop(paste("the CSV file", i, "is empty"))
  }
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
  df_EEA$DatetimeBegin <-
    with_tz(df_EEA$DatetimeBegin, tz = "Etc/GMT-1")
  df_EEA$DatetimeEnd <- as_datetime(df_EEA$DatetimeEnd)
  df_EEA$DatetimeEnd <-
    with_tz(df_EEA$DatetimeEnd, tz = "Etc/GMT-1")
  year <- substr(df_EEA$DatetimeBegin, 1, 4)
  year1 <- unique(year)
  if (length(year1) != 1) {
    stop(paste(i, "with more than 1 year"))
  }
  return(df_EEA)
}

#identify_problematic_station ####
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
  sum(c(df_EEA1$Concentration - df_EEA2$Concentration),
      na.rm = T) ==
    0 &
    length(setdiff(df_EEA1$DatetimeBegin[is.na(df_EEA1$Concentration)],
                   df_EEA2$DatetimeBegin[is.na(df_EEA2$Concentration)])) ==
    0 &
    length(setdiff(df_EEA1$DatetimeBegin[is.na(df_EEA2$Concentration)],
                   df_EEA2$DatetimeBegin[is.na(df_EEA1$Concentration)])) ==
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
            df_EEA2$Concentration[df_EEA2$DatetimeBegin %in% intersect(df_EEA1$DatetimeBegin, df_EEA2$DatetimeBegin)]),
        na.rm = T) == 0
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
          data.frame(DatetimeBegin = DatetimeBegin,
                     DatetimeEnd = DatetimeEnd),
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

#HtoD ####
lag_na <- function(sub) {
  sub$lag_na <- NA
  # apply(sub, 1, function(x)
  sub$lag_na[1] <- 0
  if (is.na(sub$Concentration[1])) {
    sub$lag_na[1] <- 1
  }
  for (i in 2:nrow(sub)) {
    if (is.na(sub$Concentration[i]))
    {
      sub$lag_na[i] <- sub$lag_na[i - 1] + 1
    } else{
      sub$lag_na[i] <- 0
    }
    if (as_date(sub$DatetimeBegin[i]) != as_date(sub$DatetimeBegin[i -
                                                                   1]) &
        sub$lag_na[i] != 0)
    {
      sub$lag_na[i] <- sub$lag_na[i] - sub$lag_na[i - 1]
    }
  }
  date_tobe_excl <-
    unique(as_date(sub$DatetimeBegin[sub$lag_na > 6]))
  return(date_tobe_excl)
}

mixed <- function(sub, s) {
  sub_d <- sub[sub$ID_AVGTIME == 3,]
  sub_h <- sub[sub$ID_AVGTIME %in% c(1, 2),]
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
  return(EEA_daily)
}

hourly <- function(sub, s) {
  DatetimeBegin <- seq.POSIXt(from = as.POSIXct(paste0(as.character(min(
    as_date(sub$DatetimeBegin)
  )), " 00:00:00"),tz = "Etc/GMT-1"),
  to = as.POSIXct(paste0(as.character(max(
    as_date(sub$DatetimeBegin)
  )), " 23:00:00"),tz = "Etc/GMT-1"),
  by = "hours")
  sub <- merge(data.frame(DatetimeBegin), sub, all.x = T)
  sub$AirQualityStation <- s
  date_tobe_excl <- lag_na(sub)
  sub <- imputation(sub, s, date_tobe_excl)
  if (nrow(sub)>0) {
    sub <- daily_average(sub, s, date_tobe_excl)
    return(sub)
  }else{
    return(sub)
  }
  
}

imputation <- function(sub, s, date_tobe_excl) {
  if (length(unique(sub$Concentration[!is.na(sub$Concentration)])) ==
      1) {
    sub$Concentration <-
      unique(sub$Concentration[!is.na(sub$Concentration)])
    sub$time <- as_date(sub$DatetimeBegin)
    print(paste0(s, " all equal"))
    return(sub)
  } else if (length(date_tobe_excl) != length(unique(as_date(sub$DatetimeBegin)))) {
    print(paste0("making kalman on ", s))
    sub$Concentration <- na_kalman(sub$Concentration)
    sub$time <- as_date(sub$DatetimeBegin)
    return(sub)
  } else {
    sub <- sub[-c(1:nrow(sub)),]
    return(sub)
  }
}

daily_average <- function(sub, s, date_tobe_excl) {
  EEA_daily <- sub %>%
    group_by(time) %>%
    summarise(
      min = min(Concentration),
      q1 = quantile(Concentration, probs = .25),
      mean = mean(Concentration),
      med = median(Concentration),
      q3 = quantile(Concentration, probs = .75),
      max = max(Concentration)
    )
  EEA_daily$AirQualityStation <- s
  EEA_daily <- EEA_daily[, c(8, 1:7)]
  names(EEA_daily)[-c(1, 2)] <-
    paste0(names(EEA_daily)[-c(1, 2)], "_", p)
  EEA_daily <- as.data.frame(EEA_daily)
  EEA_daily <- EEA_daily[!EEA_daily$time %in% date_tobe_excl,]
  return(EEA_daily)
}
