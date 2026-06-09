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

# Optional dataset loader — NULL if path missing from config or on disk.
.load_optional <- function(root, cfg, name) {
  block <- cfg$datasets[[name]]
  if (is.null(block)) return(NULL)
  path <- file.path(root, block$path)
  if (!file.exists(path)) return(NULL)
  readRDS(path)
}

# Returns a list with config + the ADaM datasets. ADTTE is loaded if present
# (it is derived by programs/02_derive_adtte.R) and is NULL otherwise.
load_study_data <- function(root = find_project_root(), cfg = load_config(root)) {
  rd <- function(p) readRDS(file.path(root, p))
  list(
    config = cfg,
    ADSL  = rd(cfg$datasets$ADSL$path),
    ADAE  = rd(cfg$datasets$ADAE$path),
    ADLB  = rd(cfg$datasets$ADLB$path),
    ADTTE = .load_optional(root, cfg, "ADTTE"),
    ADEX  = .load_optional(root, cfg, "ADEX"),
    ADVS  = .load_optional(root, cfg, "ADVS"),
    ADCM  = .load_optional(root, cfg, "ADCM"),
    ADMH  = .load_optional(root, cfg, "ADMH")
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

# Restrict to selected treatment arms (teal filter-panel equivalent).
filter_by_arms <- function(df, cfg, arms = NULL) {
  if (is.null(arms) || length(arms) == 0) return(df)
  arms <- intersect(arms, arm_levels(cfg))
  if (!"ARM" %in% names(df)) return(df)
  df %>% filter(.data$ARM %in% arms)
}

# Safety-population subject IDs, optionally restricted by arm.
safety_subject_ids <- function(adsl, cfg, arms = NULL) {
  safety_adsl(adsl, cfg) %>%
    filter_by_arms(., cfg, arms) %>%
    pull(.data$USUBJID)
}

# Event-level datasets: safety pop + optional arm filter.
filter_safety_events <- function(df, adsl, cfg, arms = NULL) {
  ids <- safety_subject_ids(adsl, cfg, arms)
  df %>%
    filter(.data$USUBJID %in% ids) %>%
    { if ("ARM" %in% names(.)) filter_by_arms(., cfg, arms) else . }
}
