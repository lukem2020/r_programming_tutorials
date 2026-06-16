# Smoke-test teal data prep and tern benchmarks vs legacy R helpers.
# Run: Rscript programs/05_smoke_test_teal.R

if (file.exists("renv/activate.R")) source("renv/activate.R")

for (f in c(
  "load_data.R", "demographics.R", "ae_analysis.R",
  "tlg_registry_load.R", "teal_adam_trim.R", "teal_study_data.R", "tlg_tern_layouts.R"
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

# IPPG01 contract: ADCM timeline datetime fields must be collision-safe.
adcm_teal <- teal_data_obj[["ADCM"]]
stopifnot(
  !is.null(adcm_teal),
  all(c("CMASTDTM", "CMAENDTM") %in% names(adcm_teal))
)

# LBT04 contract: abnormality variables must be factorized and filterable.
adlb_teal <- teal_data_obj[["ADLB"]]
stopifnot(
  !is.null(adlb_teal),
  all(c("ANRIND", "BNRIND", "PARAM", "LBCAT", "ONTRTFL") %in% names(adlb_teal)),
  all(vapply(adlb_teal[c("ANRIND", "BNRIND", "PARAM", "LBCAT", "ONTRTFL")], is.factor, logical(1)))
)
adlb_abn <- filter_abnormality_records(adlb_teal)
na_lvl <- abnormality_na_level()
anrind_chr <- as.character(adlb_abn$ANRIND)
param_chr <- as.character(adlb_abn$PARAM)
lbcat_chr <- as.character(adlb_abn$LBCAT)
ontrtfl_chr <- as.character(adlb_abn$ONTRTFL)
stopifnot(
  nrow(adlb_abn) > 0L,
  all(ontrtfl_chr %in% "Y"),
  all(!is.na(anrind_chr) & anrind_chr != na_lvl),
  all(!is.na(param_chr) & param_chr != na_lvl),
  all(!is.na(lbcat_chr) & lbcat_chr != na_lvl)
)

# LBL02A_RLS contract: Roche Safety Lab listing builds and exports for display.
source(file.path("R", "lbl02a_rls_listing.R"))
source(file.path("R", "derive_adqs.R"))
lbl02a_lst <- build_lbl02a_rls_listing(adlb_teal)
stopifnot(
  inherits(lbl02a_lst, "listing_df"),
  nrow(lbl02a_lst) > 0L,
  nchar(rlistings::export_as_txt(lbl02a_lst, paginate = FALSE)) > 0L
)
sid <- adlb_teal$USUBJID[[1]]
lbl02a_one <- build_lbl02a_rls_listing(adlb_teal, usubjid = sid)
stopifnot(
  inherits(lbl02a_one, "listing_df"),
  nrow(lbl02a_one) > 0L,
  nrow(lbl02a_one) < nrow(lbl02a_lst)
)
ch <- lbl02a_rls_patient_choices(adlb_teal)
stopifnot(length(ch) > 0L, sid %in% ch)
lbl02a_txt <- rlistings::export_as_txt(lbl02a_lst, paginate = FALSE)
stopifnot(!grepl("\\(U/L\\) \\(U/L\\)", lbl02a_txt))

# AOVT01 contract: derived ADQS supports ANCOVA table build.
adqs <- derive_adqs_for_aovt(st$ADVS, st$ADSL %>% dplyr::filter(.data$SAFFL == "Y"))
stopifnot(nrow(adqs) > 0L, all(c("CHG", "BASE", "STRATA1", "ARMCD", "PARAMCD", "AVISIT") %in% names(adqs)))
stopifnot(length(unique(as.character(adqs$AVISIT))) >= 2L)
aovt01_tbl <- build_aovt01(list(ADSL = adsl, ADQS = adqs))
stopifnot(!is.null(aovt01_tbl), length(class(aovt01_tbl)) > 0L)
aovt01_txt <- paste(rtables::toString(aovt01_tbl), collapse = "\n")
stopifnot(nchar(aovt01_txt) > 100L, grepl("Adjusted Mean", aovt01_txt))

# COXT01 contract: ADTTE carries ADSL demographics for Cox covariates.
adtte_teal <- teal_data_obj[["ADTTE"]]
stopifnot(
  !is.null(adtte_teal),
  all(c("AVAL", "CNSR", "PARAMCD", "AGE", "RACE", "SEX") %in% names(adtte_teal))
)

cat("Teal smoke test passed.\n")
