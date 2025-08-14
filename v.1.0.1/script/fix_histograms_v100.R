library(doParallel)
library(foreach)
library(httr)
registerDoParallel(cores = detectCores())
library(lubridate)
setwd("AQ-EEA/v.1.0.0") #version

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


library(ggplot2)
foreach(p = pol[7], .combine = rbind) %dopar% {
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
  for (perc in c(.9999, .99999)) {
    thr <- perc * length(pol_all)
    thr <- round(thr, 0)
    pol_thr <- pol_all[thr]
    pol_cut <- pol_all[pol_all >= pol_thr]
    iter <- which(c(.9999, .99999) == perc)
    name_file <-
      paste0("~/Library/Mobile Documents/com~apple~CloudDocs/Lavoro/PhD Bergamo/GRINS/GitHub/GRINS-Spoke0-WP2/AQ-EEA/v.1.0.1/plot/anomalies/hist_",
             p,
             "_fix_",
             iter,
             "_thr.pdf")
    pdf(name_file,width = 3.5, height = 3)
    print(
      ggplot(data = df_EEA[df_EEA$Concentration > pol_thr, ]) +
        geom_histogram(aes(
          x = Concentration, fill = as.factor(AirQualityStation)
        ),
        col = "black") +
        theme_light() +
        theme(legend.position = "none") +
        scale_x_continuous(breaks = 10 ^ c(1:10), trans = "pseudo_log", name = expression(mu*g/m^3)) +
        scale_y_continuous(breaks = 10 ^ c(1:20), trans = "pseudo_log") 
    )
    dev.off()
  }
}
