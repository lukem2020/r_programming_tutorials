# Deploy a Shiny app to shinyapps.io.
# Run from project root: Rscript deploy_app.R
#
# Prerequisites:
#   1. Copy config/deploy.example.yml → config/deploy.yml
#   2. Fill in account, token, secret from shinyapps.io (Account → Tokens)
#   3. renv::restore() passes locally
#   4. For teal: programs/04_prepare_teal_adam.R and programs/05_smoke_test_teal.R
#
# Set deploy.app in config/deploy.yml to "teal" (default) or "legacy".

suppressPackageStartupMessages({
  library(yaml)
})

`%||%` <- function(x, y) if (is.null(x)) y else x

root <- normalizePath(".", winslash = "/", mustWork = FALSE)
if (file.exists(file.path(root, "renv", "activate.R"))) {
  source(file.path(root, "renv", "activate.R"))
}
Sys.setenv(RENV_CONFIG_SANDBOX_ENABLED = "FALSE")

run_smoke_test <- function(script, project_root) {
  owd <- getwd()
  on.exit(setwd(owd), add = TRUE)
  setwd(project_root)
  cat("Running smoke test:", normalizePath(script, winslash = "/"), "\n")
  tryCatch(
    source(script, local = FALSE),
    error = function(e) {
      stop("Smoke test failed: ", conditionMessage(e), call. = FALSE)
    }
  )
  invisible(TRUE)
}

source(file.path(root, "programs", "pin_renv_remotes.R"))
source(file.path(root, "programs", "patch_deploy_manifest.R"))

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
app_target <- tolower(deploy$app %||% "teal")

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

legacy_app_files <- c(
  "app.R", "R/", "config/study_config.yml", "data/adam/", "renv.lock", ".Rprofile"
)

teal_app_files <- c(
  "app.R",
  "../R/",
  "../config/study_config.yml",
  "../config/tlg_registry.yml",
  "../config/dataset_inventory.yml",
  "../data/adam/",
  "../renv.lock",
  "../.Rprofile"
)

if (app_target == "teal") {
  app_dir <- file.path(root, "app_teal")
  app_files <- deploy$app_files %||% teal_app_files
  smoke_script <- file.path(root, "programs", "05_smoke_test_teal.R")
  prep_hint <- "Rscript programs/04_prepare_teal_adam.R"
} else if (app_target == "legacy") {
  app_dir <- root
  app_files <- deploy$app_files %||% legacy_app_files
  smoke_script <- file.path(root, "programs", "03_smoke_test.R")
  prep_hint <- NULL
} else {
  stop("deploy.app must be 'teal' or 'legacy', not: ", app_target)
}

if (!dir.exists(app_dir)) {
  stop("Application directory not found: ", app_dir)
}

if (isTRUE(deploy$smoke_test %||% TRUE)) {
  if (!file.exists(smoke_script)) {
    stop("Smoke test not found: ", smoke_script)
  }
  run_smoke_test(smoke_script, root)
  cat("Smoke test passed.\n")
}

if (!is.null(prep_hint)) {
  need <- c(
    file.path(root, "config", "tlg_registry.yml"),
    file.path(root, "config", "dataset_inventory.yml"),
    file.path(root, "data", "adam", "ADSL.rds")
  )
  if (!all(file.exists(need))) {
    stop(
      "Teal deploy bundle is missing prepared data/config. Run first:\n  ",
      prep_hint,
      call. = FALSE
    )
  }
}

cat("Configuring shinyapps.io account:", sa$account, "\n")
rsconnect::setAccountInfo(
  name = sa$account,
  token = sa$token,
  secret = sa$secret
)

cat(
  "Deploying", sa$app_name,
  sprintf("(%s app) to shinyapps.io ...\n", app_target)
)

lockfile_path <- file.path(root, "renv.lock")
pin_renv_lockfile_remotes(lockfile_path)

cat("Writing deployment manifest (renv lockfile + GitHub SHA pins)...\n")
manifest_path <- file.path(app_dir, "manifest.json")
rsconnect::writeManifest(
  appDir = app_dir,
  appPrimaryDoc = "app.R",
  appFiles = app_files,
  envManagement = TRUE,
  envManagementR = TRUE,
  packageRepositoryResolutionR = "lockfile"
)
patch_result <- patch_manifest_from_lockfile(manifest_path, lockfile_path)
tern_src <- jsonlite::fromJSON(manifest_path, simplifyVector = FALSE)$packages$tern$Source
if (!identical(tern_src, "github")) {
  stop(
    "Failed to pin tern to GitHub in manifest.json (Source is ", tern_src, ")",
    call. = FALSE
  )
}

rsconnect::deployApp(
  appDir = app_dir,
  appName = sa$app_name,
  manifestPath = "manifest.json",
  logLevel = deploy$log_level %||% "normal",
  forceUpdate = isTRUE(deploy$force_update)
)

cat("\nDone. Open: https://", sa$account, ".shinyapps.io/", sa$app_name, "/\n", sep = "")
