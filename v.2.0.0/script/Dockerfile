FROM rocker/r-ver:4.3.3

COPY 1_EEA_download.R /EEA_download.R

RUN mkdir data/ && \
    mkdir data/raw

RUN apt update && \
    apt install vim -y

# Install required R packages
RUN R -e "install.packages('httr')" && \
    R -e "install.packages('jsonlite')" && \
    R -e "install.packages('lubridate')" && \
    R -e "install.packages('httr2')" && \
    R -e "install.packages('arrow')" && \
    R -e "install.packages('glue')"

RUN R -e "install.packages('httr2')"

CMD ["Rscript","EEA_download.R"]
