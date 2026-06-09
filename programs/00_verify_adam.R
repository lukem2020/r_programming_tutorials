# Verify ADaM datasets in data/adam/ — STUDYID, row counts, safety-pop overlap.
# Run from project root: Rscript programs/00_verify_adam.R

suppressPackageStartupMessages({
  library(dplyr)
  library(yaml)
})

root <- if (file.exists("config/study_config.yml")) "." else
  normalizePath(file.path(".."), winslash = "/", mustWork = FALSE)
cfg <- yaml::read_yaml(file.path(root, "config", "study_config.yml"))
adam_dir <- file.path(root, "data", "adam")

rd <- function(f) {
  p <- file.path(adam_dir, f)
  if (!file.exists(p)) return(NULL)
  readRDS(p)
}

adsl <- rd("ADSL.rds")
if (is.null(adsl)) stop("ADSL.rds not found — run programs/01_prepare_adam.R first")

safe_ids <- adsl %>%
  filter(.data$SAFFL == "Y") %>%
  pull(.data$USUBJID)

cat("=== ADaM verification (", cfg$study$id, ") ===\n", sep = "")
cat("Safety population N:", length(safe_ids), "\n\n")

domains <- c("ADSL", "ADAE", "ADLB", "ADEX", "ADVS", "ADCM", "ADMH", "ADTTE")
for (dom in domains) {
  path <- cfg$datasets[[dom]]$path
  f <- if (!is.null(path)) basename(path) else paste0(dom, ".rds")
  x <- rd(f)
  if (is.null(x)) {
    cat(sprintf("%-6s  MISSING (%s)\n", dom, f))
    next
  }
  sid <- paste(unique(x$STUDYID), collapse = ", ")
  overlap <- if ("USUBJID" %in% names(x)) sum(x$USUBJID %in% safe_ids) else NA_integer_
  cat(sprintf("%-6s  nrow=%6d  cols=%3d  STUDYID=%s  safety_rows=%s\n",
              dom, nrow(x), ncol(x), sid,
              if (is.na(overlap)) "n/a" else overlap))
}

cat("\nDone.\n")
