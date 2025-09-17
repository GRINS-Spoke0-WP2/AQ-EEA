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



lag_na <- function(sub) {
  sub$lag_na <- NA
  day   <- as.Date(format(sub$DatetimeBegin, "%Y-%m-%d"))
  is_na <- is.na(sub$Concentration)
  new_day <- c(TRUE, day[-1] != day[-length(day)])
  grp <- cumsum(!is_na | new_day)
  sub$lag_na <- ifelse(is_na, ave(is_na, grp, FUN = cumsum), 0L)
  date_tobe_excl <-
    unique(as_date(sub$DatetimeBegin[sub$lag_na > 6]))
  return(date_tobe_excl)
}

library(lubridate)
load("AQ-EEA/v.1.0.0/data/preprocessing/1p_1y_subsetted/NO2_2023.Rdata")
staz <- df_EEA$AirQualityStation[1]
s <- staz
sub <- subset(df_EEA, AirQualityStation == staz)
class(sub$DatetimeBegin)
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
sub$AirQualityStation <- unique(sub$AirQualityStation[!is.na(sub$AirQualityStation)])

date_tobe_excl <- lag_na(sub)
print(paste0("making kalman on ", s))
na_idx_k <- is.na(sub$Concentration)
if (na_idx_k[1] == T) {
  na_rm_init <- match(FALSE, na_idx_k)
  str1 <- StructTS(sub$Concentration[-c(1:na_rm_init)], type = "level", fixed = c(NA,1))
} else{
  str1 <- StructTS(sub$Concentration, type = "level")
}
library(imputeTS)
na_k_aut <- na_kalman(sub$Concentration)
y_kalm <- KalmanSmooth(sub$Concentration, str1$model)
# my_y_kalm <- my_kalman_smoother(sub$Concentration) # GO DOWN!
sd_eps <- 1
sd_eta <- as.numeric(sqrt(str1$coef[1]))
kalman_start <- list(
  a_1 = sub$Concentration[na_rm_init+1],
  P_1 = (sd_eps^2) + (sd_eta^2),
  sigma_eta = sd_eta,
  sigma_eps = sd_eps
)

my_y_kalm <- my_kalman_smoother(sub$Concentration,
                                kalman_start = kalman_start)

library(ggplot2)

set.seed(18)
d <- sample(as_date(sub$DatetimeBegin[is.na(sub$Concentration)]),1)
d_x <- seq.POSIXt(
  from = as.POSIXct(paste0(as.character(min(
    as_date(d)
  )), " 00:00:00"), tz = "Etc/GMT-1"),
  to = as.POSIXct(paste0(as.character(max(
    as_date(d)
  )), " 23:00:00"), tz = "Etc/GMT-1"),
  by = "hours"
)
sub$state <- my_y_kalm$state
sub$var <- my_y_kalm$variance
ggplot(sub,aes(x=DatetimeBegin))+
  geom_line(aes(y=Concentration))+
  coord_cartesian(xlim = c(d_x[1],d_x[24]),ylim = c(0,75))+
  geom_line(aes(y=state),col="red",linetype=2)+
  geom_ribbon(aes(ymin=state - 1.96*sqrt(var),
                  ymax=state + 1.96*sqrt(var)),alpha=.1,col="orange",fill="yellow")+
  theme_light()+
  ylab(expression(mu*g/m^3))+
  xlab("time")

ggsave("AQ-EEA/v.1.0.2/plot/missing_imputation_uncertainty.pdf",width = 7, height = 3)

##
data_y <- sub$Concentration[-c(1:na_rm_init)]

sub$Concentration[na_idx_k] <- c(y_kalm[[1]])[na_idx_k]
sub$var_kalman <- c(y_kalm[[2]])
sub$var_kalman[!na_idx_k] <- 0
# sub$Concentration <- na_kalman(sub$Concentration)
sub$time <- as_date(sub$DatetimeBegin)
