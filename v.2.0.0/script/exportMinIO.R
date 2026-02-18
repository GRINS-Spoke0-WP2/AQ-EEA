install.packages("aws.s3")

library(aws.s3)

# Minio S3:
# endpoint: 192.168.0.51:82
# bucket: aqclim-bkt
# user: aqclim-user
# password: q96f!MyFAgxnE1dD#U$5
# skippare controllo certificato https per produzione

Sys.setenv(
  "AWS_ACCESS_KEY_ID" = "aqclim-user",
  "AWS_SECRET_ACCESS_KEY" = "q96f!MyFAgxnE1dD#U$5",
  "AWS_DEFAULT_REGION" = "us-east-1",
  "AWS_S3_ENDPOINT" = "http://192.168.0.51:82"   # MinIO senza HTTPS
)

put_object(
  file = "dataset.csv",          # file locale
  object = "dataset.csv",        # nome del file remoto
  bucket = "aqclim-bkt",
  base_url = Sys.getenv("AWS_S3_ENDPOINT"),
  use_https = FALSE,             # IMPORTANTISSIMO - MinIO spesso non usa SSL
  use_path_style = TRUE          # NECESSARIO per MinIO
)


