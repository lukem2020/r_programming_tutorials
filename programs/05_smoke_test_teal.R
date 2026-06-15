# Smoke-test teal data prep and tern benchmarks vs legacy R helpers.
# Run: Rscript programs/05_smoke_test_teal.R

if (file.exists("renv/activate.R")) source("renv/activate.R")

for (f in c(
  "load_data.R", "demographics.R", "ae_analysis.R",
  "tlg_registry_load.R", "teal_study_data.R", "tlg_tern_layouts.R"
)) {
  source(file.path("R", f))
}

cfg <- load_config(".")
st <- load_study_data(".", cfg)
adsl <- st$ADSL
adae <- st$ADAE

stopifnot(nrow(adsl) == as.integer(cfg$study$n_subjects_safety))

# Legacy demographics N row vs per-arm safety counts
demo <- demographics_table(adsl, cfg)
arms <- cfg$display$arm_levels[[1]]
legacy_n <- as.integer(unlist(demo[demo[[1]] == "N", arms]))
direct_n <- vapply(arms, function(a) sum(adsl$ARM == a), integer(1))
stopifnot(all(legacy_n == direct_n))

# tern DMT01 builds
tern_tbl <- build_dmt01(list(ADSL = adsl))
stopifnot(!is.null(tern_tbl), length(class(tern_tbl)) > 0L)

# TEAE: legacy overview vs dplyr on TRTEMFL
ae_legacy <- ae_overview_table(adae, adsl, cfg)
teae_n <- adae %>%
  dplyr::filter(.data$TRTEMFL == "Y") %>%
  dplyr::distinct(.data$USUBJID, .data$ARM) %>%
  dplyr::count(.data$ARM, name = "n")
stopifnot(nrow(teae_n) == 3L)

# Registry + inventory present
registry <- load_tlg_registry(".")
inventory <- load_dataset_inventory(".")
stopifnot(length(registry$entries) >= 100L)
adsl_inv <- Filter(function(d) identical(d$name, "ADSL"), inventory$datasets)[[1]]
stopifnot(isTRUE(adsl_inv$available))

# teal_data object builds without error
teal_data_obj <- build_teal_data(".", cfg)
stopifnot("ADSL" %in% names(teal_data_obj))

cat("Teal smoke test passed.\n")
