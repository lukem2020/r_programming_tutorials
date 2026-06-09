# Deploy the MDR Safety Dashboard to shinyapps.io.
# Run from project root: Rscript deploy_app.R
#
# Prerequisites:
#   1. Copy config/deploy.example.yml → config/deploy.yml
#   2. Fill in account, token, secret from shinyapps.io (Account → Tokens)
#   3. renv::restore() and programs/03_smoke_test.R pass locally

suppressPackageStartupMessages({
  library(yaml)
})

`%||%` <- function(x, y) if (is.null(x)) y else x

root <- normalizePath(".", winslash = "/", mustWork = FALSE)
cfg_path <- file.path(root, "config", "deploy.yml")

if (!file.exists(cfg_path)) {
  stop(
    "Missing config/deploy.yml\n",
    "Copy config/deploy.example.yml to config/deploy.yml and add your shinyapps.io credentials."
  )
}

cfg <- read_yaml(cfg_path)
sa <- cfg$shinyapps %||% list()
deploy <- cfg$deploy %||% list()

required <- c("account", "token", "secret", "app_name")
missing <- setdiff(required, names(sa))
if (length(missing) > 0L) {
  stop("config/deploy.yml is missing shinyapps fields: ", paste(missing, collapse = ", "))
}

placeholder <- function(x) {
  is.na(x) || !nzchar(x) || grepl("PASTE_|your-shinyapps", x, ignore.case = TRUE)
}
if (any(vapply(sa[required], placeholder, logical(1)))) {
  stop("Replace placeholder values in config/deploy.yml before deploying.")
}

if (!requireNamespace("rsconnect", quietly = TRUE)) {
  stop("Install rsconnect first: install.packages(\"rsconnect\")")
}

default_app_files <- c(
  "app.R", "R/", "config/study_config.yml", "data/adam/", "renv.lock", ".Rprofile"
)
app_files <- deploy$app_files %||% default_app_files

cat("Configuring shinyapps.io account:", sa$account, "\n")
rsconnect::setAccountInfo(
  name = sa$account,
  token = sa$token,
  secret = sa$secret
)

cat("Deploying", sa$app_name, "to shinyapps.io ...\n")
rsconnect::deployApp(
  appDir = root,
  appName = sa$app_name,
  appFiles = app_files,
  logLevel = deploy$log_level %||% "normal",
  forceUpdate = isTRUE(deploy$force_update)
)

cat("\nDone. Open: https://", sa$account, ".shinyapps.io/", sa$app_name, "/\n", sep = "")
