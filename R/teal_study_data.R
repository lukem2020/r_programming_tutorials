# Build teal_data object and global filters for the TLG Catalog app.

suppressPackageStartupMessages({
  library(teal.data)
  library(teal.slice)
})

CORE_STUDY_DATASETS <- c("ADSL", "ADAE", "ADLB", "ADVS", "ADCM", "ADEX", "ADMH", "ADTTE")
OPTIONAL_ADAM_DATASETS <- c("ADEG", "ADAB", "ADPC", "ADPP", "ADQS")

load_teal_dataset <- function(root, cfg, nm) {
  block <- cfg$datasets[[nm]]
  if (is.null(block)) return(NULL)
  path <- file.path(root, block$path)
  if (!file.exists(path)) return(NULL)
  df <- readRDS(path)
  if (nm == "ADTTE" && !"AVALU" %in% names(df)) df$AVALU <- "DAY"
  if (nm == "ADTTE" && !"AGE" %in% names(df)) {
    adsl_path <- file.path(root, "data", "adam", "ADSL.rds")
    if (file.exists(adsl_path)) {
      df <- merge_adtte_demographics(df, readRDS(adsl_path))
    }
  }
  if (nm == "ADEX") {
    df <- prep_adex_for_teal(df)
  } else if (nm == "ADLB") {
    df <- add_bds_avalu(df)
  } else if (nm == "ADVS") {
    df <- add_bds_avalu(df)
  } else if (nm == "ADCM") {
    df <- prep_adcm_for_teal(df)
  }
  trim_teal_dataset(df, nm, cfg)
}

build_teal_data <- function(
  root = find_project_root(),
  cfg = load_config(root),
  datasets = NULL
) {
  if (is.null(datasets)) datasets <- CORE_STUDY_DATASETS
  adam_dir <- file.path(root, "data", "adam")

  ds_list <- list()
  for (nm in datasets) {
    if (nm %in% CORE_STUDY_DATASETS) {
      df <- load_teal_dataset(root, cfg, nm)
      if (!is.null(df)) ds_list[[nm]] <- df
    } else if (nm %in% OPTIONAL_ADAM_DATASETS) {
      path <- file.path(adam_dir, paste0(nm, ".rds"))
      if (file.exists(path)) {
        ds_list[[nm]] <- trim_teal_dataset(readRDS(path), nm, cfg)
      } else if (identical(nm, "ADQS")) {
        advs_path <- file.path(adam_dir, "ADVS.rds")
        adsl_path <- file.path(adam_dir, "ADSL.rds")
        if (file.exists(advs_path) && file.exists(adsl_path)) {
          if (!exists("derive_adqs_for_aovt", mode = "function")) {
            source(file.path(root, "R", "derive_adqs.R"), local = FALSE)
          }
          adqs <- derive_adqs_for_aovt(readRDS(advs_path), readRDS(adsl_path))
          if (nrow(adqs) > 0L) {
            ds_list[[nm]] <- trim_teal_dataset(adqs, nm, cfg)
          }
        }
      }
    }
  }

  if (is.null(ds_list$ADSL)) {
    stop("ADSL is required for the teal app.", call. = FALSE)
  }

  data <- do.call(teal_data, ds_list)
  present <- intersect(names(teal.data::default_cdisc_join_keys), names(data))
  teal.data::join_keys(data) <- teal.data::default_cdisc_join_keys[present]
  data
}

teal_arm_filter <- function(datanames = CORE_STUDY_DATASETS) {
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
