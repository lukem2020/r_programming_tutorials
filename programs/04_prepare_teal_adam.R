# Prepare teal-ready ADaM datasets for the TLG Catalog teal app.
# Run from project root: Rscript programs/04_prepare_teal_adam.R

suppressPackageStartupMessages({
  library(dplyr)
  library(yaml)
  library(tern)
})

source(file.path("R", "load_data.R"))
source(file.path("R", "teal_adam_trim.R"))
source(file.path("R", "derive_adqs.R"))

study_id <- "CDISCPILOT01"
adam_dir <- file.path("data", "adam")
dir.create(adam_dir, recursive = TRUE, showWarnings = FALSE)

cfg <- load_config(".")
st <- load_study_data(".", cfg)

# Optional pharmaverseadam domains present in the installed package (study-aligned subset).
optional_objs <- c("adeg", "adab", "adpc", "adpp")
optional_loaded <- list()

if (requireNamespace("pharmaverseadam", quietly = TRUE)) {
  pkg_data <- utils::data(package = "pharmaverseadam")$results[, "Item"]
  for (obj in intersect(optional_objs, tolower(pkg_data))) {
    tryCatch({
      data(list = obj, package = "pharmaverseadam")
      x <- get(obj)
      if ("STUDYID" %in% names(x)) {
        x <- dplyr::filter(x, .data$STUDYID == study_id)
      }
      if (nrow(x) > 0L && "USUBJID" %in% names(x)) {
        sl_ids <- unique(st$ADSL$USUBJID)
        x <- dplyr::filter(x, .data$USUBJID %in% sl_ids)
      }
      if (nrow(x) > 0L) {
        nm <- toupper(obj)
        optional_loaded[[nm]] <- x
        out <- file.path(adam_dir, paste0(nm, ".rds"))
        saveRDS(x, out)
        cat(" Optional", nm, ":", nrow(x), "rows ->", out, "\n")
      }
    }, error = function(e) invisible(NULL))
  }
}

explicit_na_df <- function(df) {
  if (!requireNamespace("tern", quietly = TRUE)) return(df)
  char_cols <- names(df)[vapply(df, is.character, logical(1))]
  if (length(char_cols) == 0L) return(df)
  tern::df_explicit_na(df, omit_columns = setdiff(names(df), char_cols))
}

arm_levels <- unlist(cfg$display$arm_levels, use.names = FALSE)

prep_adsl <- function(adsl) {
  adsl %>%
    filter(.data$SAFFL == "Y") %>%
    mutate(
      ARM = factor(.data$ARM, levels = arm_levels),
      ACTARM = factor(.data$ARM, levels = arm_levels)
    ) %>%
    explicit_na_df()
}

add_ae_flags <- function(adae) {
  adae %>%
    mutate(
      ARM = factor(.data$ARM, levels = arm_levels),
      FATAL = .data$AESDTH == "Y",
      SER = .data$AESER == "Y",
      SEV = .data$AESEV == "SEVERE",
      REL = !is.na(.data$AEREL) & .data$AEREL != "NONE",
      WD = .data$AEACN == "DRUG WITHDRAWN",
      USUBJID_AESEQ = paste(.data$USUBJID, .data$AESEQ, sep = "@@")
    ) %>%
    explicit_na_df()
}

prep_adcm <- function(adcm) {
  adcm %>%
    mutate(
      ARM = factor(.data$ARM, levels = arm_levels),
      CMASTDTM = .data$ASTDTM,
      CMAENDTM = .data$AENDTM
    ) %>%
    explicit_na_df()
}

prep_bds_abnormality_chars <- function(df) {
  if (is.null(df) || !requireNamespace("tern", quietly = TRUE)) return(df)
  cols <- intersect(
    c("ANRIND", "BNRIND", "AVISIT", "PARAM", "LBCAT", "ONTRTFL", "ABLFL", "PARAMCD", "ARM"),
    names(df)
  )
  if (length(cols) == 0L) return(df)
  tern::df_explicit_na(df, omit_columns = setdiff(names(df), cols))
}

prep_bds <- function(df, skip_explicit_na = FALSE) {
  if (is.null(df)) return(NULL)
  out <- df %>%
    mutate(ARM = factor(.data$ARM, levels = arm_levels))
  if (skip_explicit_na) prep_bds_abnormality_chars(out) else explicit_na_df(out)
}

ADSL <- prep_adsl(st$ADSL)
ADAE <- add_ae_flags(st$ADAE %>% filter(.data$TRTEMFL == "Y"))
ADLB <- prep_bds(st$ADLB, skip_explicit_na = TRUE)
ADVS <- prep_bds(st$ADVS, skip_explicit_na = TRUE)
ADCM <- prep_adcm(st$ADCM)
ADEX <- prep_bds(st$ADEX)
ADMH <- prep_bds(st$ADMH)
ADTTE <- if (!is.null(st$ADTTE)) merge_adtte_demographics(prep_bds(st$ADTTE), ADSL) else NULL
ADQS <- derive_adqs_for_aovt(st$ADVS, st$ADSL %>% filter(.data$SAFFL == "Y"))
if (nrow(ADQS) > 0L) {
  ADQS <- ADQS %>% mutate(ARM = factor(.data$ARM, levels = arm_levels))
}

saveRDS(ADSL, file.path(adam_dir, "ADSL.rds"))
saveRDS(ADAE, file.path(adam_dir, "ADAE.rds"))
saveRDS(ADLB, file.path(adam_dir, "ADLB.rds"))
saveRDS(ADVS, file.path(adam_dir, "ADVS.rds"))
saveRDS(ADCM, file.path(adam_dir, "ADCM.rds"))
saveRDS(ADEX, file.path(adam_dir, "ADEX.rds"))
saveRDS(ADMH, file.path(adam_dir, "ADMH.rds"))
if (!is.null(ADTTE)) saveRDS(ADTTE, file.path(adam_dir, "ADTTE.rds"))
if (nrow(ADQS) > 0L) saveRDS(ADQS, file.path(adam_dir, "ADQS.rds"))

cat(" Teal-ready ADaM saved to data/adam/\n")

inventory <- list(
  study_id = study_id,
  updated = as.character(Sys.time()),
  datasets = list(
    list(name = "ADSL", path = "data/adam/ADSL.rds", available = TRUE, rows = nrow(ADSL)),
    list(name = "ADAE", path = "data/adam/ADAE.rds", available = TRUE, rows = nrow(ADAE)),
    list(name = "ADLB", path = "data/adam/ADLB.rds", available = TRUE, rows = nrow(ADLB)),
    list(name = "ADVS", path = "data/adam/ADVS.rds", available = TRUE, rows = nrow(ADVS)),
    list(name = "ADCM", path = "data/adam/ADCM.rds", available = TRUE, rows = nrow(ADCM)),
    list(name = "ADEX", path = "data/adam/ADEX.rds", available = TRUE, rows = nrow(ADEX)),
    list(name = "ADMH", path = "data/adam/ADMH.rds", available = TRUE, rows = nrow(ADMH)),
    list(name = "ADTTE", path = "data/adam/ADTTE.rds", available = !is.null(ADTTE),
         rows = if (!is.null(ADTTE)) nrow(ADTTE) else 0L),
    list(name = "ADQS", path = "data/adam/ADQS.rds", available = nrow(ADQS) > 0L,
         rows = nrow(ADQS),
         source = "Derived from ADVS Week 12 change scores for AOVT01")
  )
)

for (nm in names(optional_loaded)) {
  inventory$datasets <- c(inventory$datasets, list(
    list(name = nm, path = file.path("data/adam", paste0(nm, ".rds")),
         available = TRUE, rows = nrow(optional_loaded[[nm]]),
         source = "pharmaverseadam (study-aligned subset)")
  ))
}

missing <- c("ADAB", "ADEG", "ADPC", "ADPP")
for (nm in missing) {
  if (!nm %in% vapply(inventory$datasets, function(x) x$name, character(1))) {
    inventory$datasets <- c(inventory$datasets, list(
      list(name = nm, available = FALSE, rows = 0L,
           note = "Not available for CDISCPILOT01 in current pipeline")
    ))
  }
}

write_yaml(inventory, file.path("config", "dataset_inventory.yml"))
cat(" Wrote config/dataset_inventory.yml\n")
