# Data loading and configuration access for the MDR Safety Dashboard.
# Reads config/study_config.yml and the ADaM datasets from data/adam/.

suppressPackageStartupMessages({
  library(yaml)
  library(dplyr)
})

# Resolve the project root as the directory containing config/study_config.yml.
# Works whether the app is launched from the root, a subfolder, or a deploy bundle.
find_project_root <- function(start = getwd()) {
  d <- normalizePath(start, winslash = "/", mustWork = FALSE)
  repeat {
    if (file.exists(file.path(d, "config", "study_config.yml"))) return(d)
    parent <- dirname(d)
    if (identical(parent, d)) break
    d <- parent
  }
  getwd()
}

load_config <- function(root = find_project_root()) {
  yaml::read_yaml(file.path(root, "config", "study_config.yml"))
}

# Returns a list with config + the three ADaM datasets.
load_study_data <- function(root = find_project_root(), cfg = load_config(root)) {
  rd <- function(p) readRDS(file.path(root, p))
  list(
    config = cfg,
    ADSL = rd(cfg$datasets$ADSL$path),
    ADAE = rd(cfg$datasets$ADAE$path),
    ADLB = rd(cfg$datasets$ADLB$path)
  )
}

# Display helpers driven by config.
arm_levels <- function(cfg) unlist(cfg$display$arm_levels, use.names = FALSE)

arm_palette <- function(cfg) {
  cols <- cfg$display$arm_colors
  setNames(unlist(cols, use.names = FALSE), names(cols))
}

# Safety population (SAFFL == "Y") with ARM as an ordered factor.
safety_adsl <- function(adsl, cfg) {
  adsl %>%
    filter(.data$SAFFL == "Y") %>%
    mutate(ARM = factor(.data$ARM, levels = arm_levels(cfg)))
}

# Add an ordered ARM factor to any dataset that carries an ARM column.
with_arm_factor <- function(df, cfg) {
  df %>% mutate(ARM = factor(.data$ARM, levels = arm_levels(cfg)))
}
