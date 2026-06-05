# Setup script: run once after installing R (>= 4.1)
# Usage: Rscript scripts/setup_env.R

required_version <- "4.1.0"
if (getRversion() < required_version) {
  stop("R ", required_version, " or higher is required.")
}

message("Step 1/4: Installing renv (if needed)...")
if (!requireNamespace("renv", quietly = TRUE)) {
  install.packages("renv", repos = "https://cloud.r-project.org")
}

message("Step 2/4: Initializing renv...")
if (!file.exists("renv.lock")) {
  renv::init(bare = TRUE)
} else {
  renv::activate()
  renv::restore(prompt = FALSE)
}

core_packages <- c(
  "dplyr", "ggplot2", "lubridate", "purrr", "stringr",
  "tibble", "tidyr", "forcats", "DT", "shiny",
  "rmarkdown", "knitr"
)

message("Step 3/4: Installing core packages...")
renv::install(core_packages)

teal_packages <- c(
  "teal.data",
  "teal.slice",
  "tern",
  "rtables",
  "teal",
  "teal.modules.clinical"
)

message("Step 4/4: Installing teal ecosystem (may take several minutes)...")
tryCatch(
  renv::install(teal_packages),
  error = function(e) {
    message(
      "Teal install failed. You can still run the Shiny fallback app.\n",
      "Error: ", conditionMessage(e)
    )
  }
)

renv::snapshot(prompt = FALSE)
message("Done. Next: Rscript R/data_generation.R")
