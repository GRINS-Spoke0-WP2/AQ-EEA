load("AQ-EEA/v.1.0.1/data/AiQuClimItaly.rda")
AQ.CLIM_IT1323 <- AiQuClimItaly
load("AQ-EEA/v.1.0.1/data/Agrimonia_Dataset_v_3_0_0.Rdata")

#chosen 548 Milano Via Senato
# 45.4705
# 9.19746
meta_aq_grins <- unique(AQ.CLIM_IT1323[,c(1,3,4)])
# FIND in GRINS:
# STA.IT1016A
# 9.198056
# 45.46972

grins <- AQ.CLIM_IT1323[AQ.CLIM_IT1323$AirQualityStation=="STA.IT1016A",]
agri <- AgrImOnIA_Dataset_v_3_0_0[AgrImOnIA_Dataset_v_3_0_0$IDStations=="548",]

  
names(grins)[-2]<-paste0("grins_",names(grins)[-2])
names(agri)[-4]<-paste0("agri_",names(agri)[-4])
names(agri)[4]<-"time"
grins_agri <- merge(grins,agri,all=T)

#RMSE 
sqrt(mean((grins_agri$agri_AQ_no2 - grins_agri$grins_AQ_mean_NO2)^2,na.rm=T))

#raw data ARPA
# raw_ARPA <- read_csv("AQ-EEA/v.1.0.1/data/tech_val/RW_20250709124304_110559_5551_1.csv")
# names(raw_ARPA)
# raw_ARPA <- as.data.frame(raw_ARPA)
# head()

summary(grins_agri)
pdf("AQ-EEA/v.1.0.1/plot/tech_val.pdf",width = 7, height = 4)
ggplot(grins_agri, aes(x = time)) +
  geom_line(aes(y = grins_AQ_max_NO2, color = "Maximum in GRINS Dataset"), linetype = 1) +
  geom_line(aes(y = grins_AQ_mean_NO2, color = "Mean in GRINS Dataset"), linetype = 1) +
  geom_line(aes(y = grins_AQ_min_NO2, color = "Minimum in GRINS Dataset"), linetype = 1) +
  geom_line(aes(y = agri_AQ_no2, color = "Agrimonia Dataset"), linetype = 2) +
  scale_x_date(limits = c(as.Date("2021-01-01"), as.Date("2021-12-31"))) +
  scale_y_continuous(limits = c(0,155)) +
  scale_color_manual(
    name = "", # Title for the legend
    values = c(
      "Maximum in GRINS Dataset" = "#E41A1C", # A vibrant red (e.g., from brewer.pal("Set1", 4)[1])
      "Mean in GRINS Dataset" = "#FF7F00",    # A bright orange (e.g., from brewer.pal("Set1", 4)[2])
      "Minimum in GRINS Dataset" = "#33A02C", # A good green (e.g., from brewer.pal("Set1", 4)[3])
      "Agrimonia Dataset" = "#377EB8"     # A strong blue (e.g., from brewer.pal("Set1", 4)[4])
    ),
    labels = c(
      "Maximum in GRINS Dataset" = "GRINS maximum",
      "Mean in GRINS Dataset" = "GRINS average",
      "Minimum in GRINS Dataset" = "GRINS minimum",
      "Agrimonia Dataset" = "Agrimonia average"
    )
  ) +
  theme_light() +
  ylab(expression(mu*g/m^3)) +
  theme(
    legend.position = "bottom", #"bottom"
    legend.direction = "horizontal",# You can adjust this to "right", "left", "top", or c(x,y)
    legend.title = element_blank(), #text(size = 10, family = "serif")
    legend.text = element_text(size = 12,family = "serif")
  )+
  guides(color = guide_legend(nrow = 2)) 
  # ggtitle(label = "Comparison of daily NO2 concentrations")
dev.off()


#weather
# RW_20250625225806_701137_2001_1 <- read_csv("AQ-EEA/v.1.0.1/data/tech_val/RW_20250625225803_701137/RW_20250625225806_701137_2001_1.csv")
library(readr)
RW_20250625225806_701137_2001_1 <- read_csv("AQ-EEA/v.1.0.1/data/tech_val/RW_20250625232303_701138/RW_20250625232305_701138_9310_1.csv")
temp <- RW_20250625225806_701137_2001_1
temp$time <- temp$`Data-Ora`
temp$time <- substr(temp$time,1,10)
temp$time <- as.Date(temp$time)
temp$t2m <- temp$`Valore Medio Giornaliero`
temp <- as.data.frame(temp[,c(6,7)])
plot(temp$t2m,type="l")
# 45.815364, 9.067055
# STA.IT0771A 9.083610 45.80444
staz_we <- "STA.IT0771A"
sub_we <- AQ.CLIM_IT1323[AQ.CLIM_IT1323$AirQualityStation==staz_we,]

sub4 <- merge(sub_we,temp,all=T)

#RMSE
sqrt(mean((sub4$WE_t2m - sub4$t2m)^2,na.rm=T))

# sub4$t2m[sub4$t2m==-999]<-NA
pdf("AQ-EEA/v.1.0.1/plot/tech_val2.pdf",width = 7, height = 3)
ggplot(sub4, aes(x = time)) +
  geom_line(aes(y = WE_t2m, color = "ARPA"), linetype = 1) +
  geom_line(aes(y = t2m, color = "GRINS Dataset"), linetype = 1)+
  scale_x_date(limits = c(as.Date("2021-01-01"), as.Date("2021-12-31")))+
  # scale_y_continuous(limits = c(-10,30))+
  scale_color_manual(
    name = "Data Source", # Title for the legend
    values = c(
      "ARPA" = "#E41A1C", # A vibrant red (e.g., from brewer.pal("Set1", 4)[1])
      "GRINS Dataset" = "#FF7F00"    # A bright orange (e.g., from brewer.pal("Set1", 4)[2])
    ),
    labels = c(
      "ARPA" = "ARPA data",
      "GRINS Dataset" = "GRINS Dataset"
    )
  ) +
  theme_light() +
  ylab("°C") +
  theme(
    legend.position = "bottom", #"bottom"
    legend.direction = "horizontal",# You can adjust this to "right", "left", "top", or c(x,y)
    legend.title = element_blank(), #element_text(size = 10, family = "serif"),
    legend.text = element_text(size = 12,family = "serif")
  ) +
  guides(color = guide_legend(nrow = 1)) 
  # ggtitle(label = "Comparison of daily temperature")
dev.off()
