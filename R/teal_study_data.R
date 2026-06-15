# Build teal_data object and global filters for the TLG Catalog app.

suppressPackageStartupMessages({
  library(teal.data)
  library(teal.slice)
})

build_teal_data <- function(root = find_project_root(), cfg = load_config(root)) {
  st <- load_study_data(root, cfg)
  adam_dir <- file.path(root, "data", "adam")

  datasets <- list(
    ADSL = st$ADSL,
    ADAE = st$ADAE,
    ADLB = st$ADLB,
    ADVS = st$ADVS,
    ADCM = st$ADCM,
    ADEX = st$ADEX,
    ADMH = st$ADMH
  )
  if (!is.null(st$ADTTE)) datasets$ADTTE <- st$ADTTE

  for (nm in c("ADEG", "ADAB", "ADPC", "ADPP")) {
    path <- file.path(adam_dir, paste0(nm, ".rds"))
    if (file.exists(path)) datasets[[nm]] <- readRDS(path)
  }

  data <- do.call(teal_data, datasets)
  present <- intersect(names(teal.data::default_cdisc_join_keys), names(data))
  teal.data::join_keys(data) <- teal.data::default_cdisc_join_keys[present]
  data
}

teal_arm_filter <- function(
  datanames = c("ADSL", "ADAE", "ADLB", "ADVS", "ADCM", "ADEX", "ADMH", "ADTTE", "ADEG", "ADAB", "ADPC", "ADPP")
) {
  teal_slices(
    teal_slice(dataname = "ADSL", varname = "ARM", title = "Treatment arm"),
    module_specific = FALSE
  )
}

study_header <- function(cfg) {
  sprintf(
    "%s (%s) | Safety N = %s",
    cfg$study$title,
    cfg$study$id,
    cfg$study$n_subjects_safety
  )
}
