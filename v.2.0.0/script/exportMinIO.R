install.packages("aws.s3")

library(aws.s3)

# Minio S3:
# endpoint: 192.168.0.51:82
# bucket: aqclim-bkt
# user: aqclim-user
# password: q96f!MyFAgxnE1dD#U$5
# skippare controllo certificato https per produzione

Sys.setenv(
  "AWS_ACCESS_KEY_ID" = "tuo_access_key",
  "AWS_SECRET_ACCESS_KEY" = "tua_secret_key",
  "AWS_DEFAULT_REGION" = "us-east-1",     # puoi lasciare così
  "AWS_S3_ENDPOINT" = "https://tuo-minio-server.example.com"  # URL del tuo MinIO
)

put_object(
  file = "dataset.csv",          # il file locale
  object = "dataset.csv",        # nome del file remoto
  bucket = "dati-progetto",
  base_url = Sys.getenv("AWS_S3_ENDPOINT"),
  use_https = TRUE
)

# 4. (Facoltativo) Controlla che sia stato caricato
get_bucket("dati-progetto", base_url = Sys.getenv("AWS_S3_ENDPOINT"))

# Suggerimento
# Se vuoi caricare direttamente un data.frame senza salvare prima il file:

# write.csv(mio_dataframe, "temp.csv", row.names = FALSE)
# put_object("temp.csv", object = "mio_dataframe.csv", bucket = "dati-progetto",
#            base_url = Sys.getenv("AWS_S3_ENDPOINT"))
