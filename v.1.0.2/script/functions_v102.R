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
  day   <- as.Date(format(sub$DatetimeBegin,"%Y-%m-%d"))
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
  EEA_daily_uncertainty <- EEA_daily
  EEA_daily_uncertainty[!is.na(EEA_daily[,3]),-c(1,2)] <- 0
  EEA_daily_uncertainty[is.na(EEA_daily[,3]),-c(1,2)] <- NA
  names(EEA_daily_uncertainty)[-c(1,2)]<-paste0("sd_",names(EEA_daily_uncertainty)[-c(1,2)])
  return(list(EEA_daily=EEA_daily,
              EEA_daily_uncertainty=EEA_daily_uncertainty))
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
  sub_list <- imputation(sub, s, date_tobe_excl)
  if (nrow(sub_list[[1]])>0) {
    daily_list <- daily_average(sub_list, s, date_tobe_excl)
    return(daily_list)
  }else{
    return(sub_list)
  }
}

imputation <- function(sub, s, date_tobe_excl) {
  if (length(unique(sub$Concentration[!is.na(sub$Concentration)])) ==
      1) { # QUESTA NO !
    sub$Concentration <-
      unique(sub$Concentration[!is.na(sub$Concentration)])
    sub$time <- as_date(sub$DatetimeBegin)
    print(paste0(s, " all equal"))
    return(sub)
  } else if (length(date_tobe_excl) != length(unique(as_date(sub$DatetimeBegin)))) {
    print(paste0("making kalman on ", s))
    na_idx_k <- is.na(sub$Concentration)
    if(na_idx_k[1]==T){
      na_rm_init <- match(FALSE,na_idx_k)
      na_rm_init <- na_rm_init - 1
      str1 <- StructTS(sub$Concentration[-c(1:na_rm_init)], type = "level", fixed = c(NA,0))
    }else{
      str1 <- StructTS(sub$Concentration,type = "level", fixed = c(NA,0))
    }
    y_kalm <- KalmanSmooth(sub$Concentration,str1$model)
    summary(y_kalm$var)
    
    # sub$Concentration[na_idx_k] <- c(y_kalm[[1]])[na_idx_k]
    # sub$Concentration <- na_kalman(sub$Concentration)
    if(na_idx_k[1]==T){
      a_1 <- sub$Concentration[na_rm_init+1]
      }else{a_1 <- sub$Concentration[1]}
    sd_eps <- 0
    sd_eta <- as.numeric(sqrt(str1$coef[1]))
    kalman_start <- list(
      a_1 = a_1,
      P_1 = (sd_eps^2) + (sd_eta^2),
      sigma_eta = sd_eta,
      sigma_eps = sd_eps
    )
    my_y_kalm <- my_kalman_smoother(sub$Concentration,
                                    kalman_start = kalman_start)
    if(length(sub$Concentration) != length(my_y_kalm$state)){
      stop("sub$concentrations and kalman smoother differ!")
    } 
    sub$Concentration[na_idx_k] <- my_y_kalm$state[na_idx_k]
    sub$time <- as_date(sub$DatetimeBegin)
    my_y_kalm$variance[my_y_kalm$variance<0] <- ceiling(my_y_kalm$variance[my_y_kalm$variance<0])
    return(list(sub=sub,Kdf=my_y_kalm)) #sub_list <- list(sub=sub,Kdf=my_y_kalm)
  } else {
    sub <- sub[-c(1:nrow(sub)),]
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
  EEA_daily <- EEA_daily[!EEA_daily$time %in% date_tobe_excl,]
  
  EEA_daily_uncertainty <- EEA_daily
  EEA_daily_uncertainty[!is.na(EEA_daily[,3]),-c(1,2)] <- 0
  names(EEA_daily_uncertainty)[-c(1,2)]<-paste0("sd_",names(EEA_daily_uncertainty)[-c(1,2)])
  Kdf <- sub_list$Kdf
  Kdf_t <- cbind(sub$time,Kdf)
  names(Kdf_t)[1]<-"time"
  for (d in unique(Kdf_t$time)) { #d <- unique(Kdf_t$time)[1] # d <- as.Date("2015-01-14") #d <- as.Date(17784)
    if (d %in% date_tobe_excl){next} # d <- as.Date("2013-05-14") d <- as.Date("2023-11-25")
    sub_kdf <- subset(Kdf_t,time==d)
    pos_imp <- which(is.na(sub_kdf$data_y))
    if(length(pos_imp)==0){next}
    n_div <- (1/24)^2
    single_variance <- sum(sub_kdf$variance[pos_imp])
    Vt_mat <- matrix(0,24,24)
    for (i in pos_imp) {
      for (j in pos_imp) {
        if(j>i){
          Vt_mat[i,j] <- sub_kdf$Pt_filter[i]*prod(
            sub_kdf$Lt[i:(j-1)])*(1-(sub_kdf$Nt[j-1]*sub_kdf$Pt_filter[j])
          )
        }
      }
    }
    covariances <- 2*sum(c(Vt_mat))
    mean_variance <- n_div *(single_variance + covariances)
    EEA_daily_uncertainty[EEA_daily_uncertainty$time==d,
                          grep("mean",names(EEA_daily_uncertainty))] <- sqrt(mean_variance)

    if(min(sub_kdf$state[pos_imp]) < min(sub_kdf$data_y,na.rm = T)){
      pos_min_imp <- which(sub_kdf$state==min(sub_kdf$state[pos_imp]))
      min_variance <- min(sub_kdf$variance[pos_min_imp])
    }else{
      min_variance <- 0
    }
    if(max(sub_kdf$state[pos_imp]) > max(sub_kdf$data_y,na.rm = T)){
      pos_max_imp <- which(sub_kdf$state==max(sub_kdf$state[pos_imp]))
      max_variance <- min(sub_kdf$variance[pos_max_imp])
    }else{
      max_variance <- 0
    }
    print(d)
    EEA_daily_uncertainty[EEA_daily_uncertainty$time==d,
                          grep("min",names(EEA_daily_uncertainty))] <- sqrt(min_variance)
    EEA_daily_uncertainty[EEA_daily_uncertainty$time==d,
                          grep("max",names(EEA_daily_uncertainty))] <- sqrt(max_variance)
    
    x_full <- c(sub_kdf$data_y)
    x_full[pos_imp] <- sub_kdf$state[pos_imp]
    x_full <- cbind(x_full,1:24)
    colnames(x_full)<-c("x","i")
    x_ordered <- x_full[order(x_full[,1]),]
    n <- nrow(x_ordered)
    for (pq in c(0.25,.5,.75)) {
      m <- (1-pq)
      j <- floor(n*pq + m)
      gamma <- n*pq + m - j
      var_j <- var_j1 <- cov_jj1 <- 0
      if (x_ordered[j,2] %in% pos_imp){
        var_j <- ((1-gamma)^2)*sub_kdf$variance[x_ordered[j,2]]
      }
      if (x_ordered[(j+1),2] %in% pos_imp){
        var_j1 <- (gamma^2)*sub_kdf$variance[x_ordered[(j+1),2]]
      }
      if(x_ordered[j,2] %in% pos_imp & x_ordered[(j+1),2] %in% pos_imp){
      cov_jj1 <- gamma * (1-gamma) * Vt_mat[x_ordered[j,2],x_ordered[(j+1),2]]}
      var_quantile <- sum(var_j,var_j1,cov_jj1)
      if(p==.25){
      var_q1 <- var_quantile
      }
      if(p==.5){
      var_med <- var_quantile
      }
      if(p==.75){
      var_q3 <- var_quantile
      }
    }
    EEA_daily_uncertainty[EEA_daily_uncertainty$time==d,
                          grep("q1",names(EEA_daily_uncertainty))] <- sqrt(var_q1)
    EEA_daily_uncertainty[EEA_daily_uncertainty$time==d,
                          grep("med",names(EEA_daily_uncertainty))] <- sqrt(var_med)
    EEA_daily_uncertainty[EEA_daily_uncertainty$time==d,
                          grep("q3",names(EEA_daily_uncertainty))] <- sqrt(var_q3)
    
  }
  
  # n <- length(x)
  # m <- (1-p)
  # j <- floor(n*p + m)
  # gamma <- n*p + m - j
  # Q <- ((1-gamma)*x[j])+(gamma*x[j+1])
  
  return(list(EEA_daily=EEA_daily,
              EEA_daily_uncertainty=EEA_daily_uncertainty))
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
    if (i==n){next}
    Pt_4smooth[i + 1] <- Pt_4smooth[i] * (1 - Kt_4smooth[i]) + (sigma_eta^2)
    if (is.na(data_y[i])) {
      Kt[i] <- 0
      at[i + 1] <- at[i]
      Pt[i + 1] <- Pt[i]  + sigma_eta^2
    }else{
      at[i + 1] <- at[i] + Kt[i] * vt[i]
      Pt[i + 1] <- Pt[i] * (1 - Kt[i]) + (sigma_eta^2)
    }
  }
  return(list(
    state = at,
    variance = Pt,
    Kalman_gain = Kt,
    var_innovations = Ft,
    innovations_hat = vt,
    data_y = data_y,
    Pt_4smooth = Pt_4smooth,
    Kt_4smooth = Kt_4smooth
  ))
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
  return(data.frame(
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
  ))
}
