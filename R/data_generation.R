# Generate synthetic CDISC-like study data for Study ABC123
# Usage: Rscript R/data_generation.R

suppressPackageStartupMessages({
  library(dplyr)
  library(lubridate)
  library(purrr)
  library(stringr)
  library(tibble)
  library(tidyr)
})

set.seed(20260605)

study_id <- "ABC123"
n_subjects <- 80
start_date <- as.Date("2025-01-15")

arms <- tibble(
  ARMCD = c("PBO", "DRG10"),
  ARM = c("Placebo", "Drug 10mg"),
  TRT01P = c("Placebo", "Drug 10mg")
)

sexes <- c("M", "F")
races <- c("WHITE", "BLACK OR AFRICAN AMERICAN", "ASIAN", "OTHER")

adsl <- tibble(
  STUDYID = study_id,
  USUBJID = sprintf("%s-%03d", study_id, seq_len(n_subjects)),
  SUBJID = sprintf("%03d", seq_len(n_subjects)),
  ARMCD = rep(arms$ARMCD, each = n_subjects / 2),
  ARM = rep(arms$ARM, each = n_subjects / 2),
  TRT01P = rep(arms$TRT01P, each = n_subjects / 2),
  AGE = round(rnorm(n_subjects, mean = 54, sd = 11)),
  AGEU = "YEARS",
  SEX = sample(sexes, n_subjects, replace = TRUE, prob = c(0.48, 0.52)),
  RACE = sample(races, n_subjects, replace = TRUE, prob = c(0.62, 0.18, 0.12, 0.08)),
  SAFFL = "Y",
  ITTFL = "Y",
  RANDDT = start_date + sample(0:45, n_subjects, replace = TRUE)
) %>%
  mutate(
    TRTSDT = RANDDT,
    TRTEDT = TRTSDT + sample(56:168, n_subjects, replace = TRUE),
    EOSDT = TRTEDT + sample(0:14, n_subjects, replace = TRUE)
  )

ae_terms <- tribble(
  ~AESOC, ~AEDECOD, ~drug_related,
  "Gastrointestinal disorders", "Nausea", TRUE,
  "Gastrointestinal disorders", "Diarrhoea", TRUE,
  "Gastrointestinal disorders", "Vomiting", TRUE,
  "Nervous system disorders", "Headache", FALSE,
  "Nervous system disorders", "Dizziness", FALSE,
  "General disorders", "Fatigue", TRUE,
  "Investigations", "Alanine aminotransferase increased", TRUE,
  "Investigations", "Aspartate aminotransferase increased", TRUE,
  "Skin disorders", "Rash", TRUE,
  "Metabolism and nutrition disorders", "Decreased appetite", FALSE
)

severity_levels <- c("MILD", "MODERATE", "SEVERE")

generate_subject_aes <- function(subject_row, max_events = 4) {
  n_events <- sample(0:max_events, 1, prob = c(0.25, 0.3, 0.25, 0.12, 0.08))
  if (n_events == 0) {
    return(tibble())
  }

  selected <- ae_terms %>%
    slice_sample(n = n_events, replace = TRUE) %>%
    mutate(
      AESEQ = row_number(),
      STUDYID = subject_row$STUDYID,
      USUBJID = subject_row$USUBJID,
      AESTDTC = subject_row$TRTSDT + sample(0:90, n_events, replace = TRUE),
      AEENDTC = AESTDTC + sample(1:21, n_events, replace = TRUE),
      AESEV = sample(severity_levels, n_events, replace = TRUE, prob = c(0.55, 0.35, 0.10)),
      AEREL = if_else(drug_related & subject_row$ARMCD == "DRG10", "RELATED", "NOT RELATED"),
      TRTEMFL = if_else(AESTDTC >= subject_row$TRTSDT, "Y", "N"),
      AESER = if_else(AESEV == "SEVERE", "Y", "N")
    ) %>%
    select(-drug_related)

  selected
}

adae <- map_dfr(split(adsl, seq_len(nrow(adsl))), generate_subject_aes)

if (nrow(adae) == 0) {
  adae <- ae_terms %>%
    slice(1) %>%
    mutate(
      STUDYID = study_id,
      USUBJID = adsl$USUBJID[1],
      AESEQ = 1L,
      AESTDTC = adsl$TRTSDT[1] + 3,
      AEENDTC = AESTDTC + 5,
      AESEV = "MILD",
      AEREL = "RELATED",
      TRTEMFL = "Y",
      AESER = "N"
    ) %>%
    select(STUDYID, USUBJID, AESEQ, AESOC, AEDECOD, AESEV, AESTDTC, AEENDTC, AEREL, TRTEMFL, AESER)
}

lab_params <- tribble(
  ~PARAMCD, ~PARAM, ~LBTESTCD, ~LBTEST, ~normal_low, ~normal_high,
  "ALT", "Alanine Aminotransferase (U/L)", "ALT", "Alanine Aminotransferase", 7, 56,
  "AST", "Aspartate Aminotransferase (U/L)", "AST", "Aspartate Aminotransferase", 10, 40,
  "BILI", "Bilirubin (mg/dL)", "BILI", "Bilirubin", 0.1, 1.2
)

visits <- tribble(
  ~AVISIT, ~ADY,
  "Baseline", 1L,
  "Week 4", 29L,
  "Week 8", 57L,
  "Week 12", 85L
)

classify_anrind <- function(value, low, high) {
  case_when(
    value < low ~ "LOW",
    value > high ~ "HIGH",
    TRUE ~ "NORMAL"
  )
}

generate_subject_labs <- function(subject_row) {
  baseline <- lab_params %>%
    mutate(
      STUDYID = subject_row$STUDYID,
      USUBJID = subject_row$USUBJID,
      AVISIT = "Baseline",
      ADY = 1L,
      ABLFL = "Y",
      BASE = NA_real_,
      AVAL = runif(n(), min = normal_low, max = normal_high),
      drug_effect = if_else(subject_row$ARMCD == "DRG10", 1.15, 1.0)
    )

  post_baseline <- crossing(
    lab_params,
    visits %>% filter(AVISIT != "Baseline")
  ) %>%
    mutate(
      STUDYID = subject_row$STUDYID,
      USUBJID = subject_row$USUBJID,
      ABLFL = "N",
      drug_effect = if_else(subject_row$ARMCD == "DRG10", 1.15, 1.0)
    )

  bind_rows(baseline, post_baseline) %>%
    group_by(USUBJID, PARAMCD) %>%
    mutate(
      BASE = first(AVAL[ABLFL == "Y"]),
      AVAL = if_else(
        ABLFL == "Y",
        AVAL,
        pmax(AVAL * drug_effect + rnorm(n(), 0, 3), 0.1)
      ),
      CHG = AVAL - BASE,
      ANRIND = classify_anrind(AVAL, normal_low, normal_high),
      AVALU = if_else(PARAMCD == "BILI", "mg/dL", "U/L"),
      LBCAT = "CHEMISTRY",
      VISITNUM = match(AVISIT, visits$AVISIT)
    ) %>%
    ungroup() %>%
    select(
      STUDYID, USUBJID, PARAMCD, PARAM, LBTESTCD, LBTEST, LBCAT,
      AVISIT, ADY, VISITNUM, AVAL, AVALU, BASE, CHG, ANRIND, ABLFL
    )
}

adlb <- map_dfr(split(adsl, seq_len(nrow(adsl))), generate_subject_labs)

output_dir <- file.path("data", "simulated")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

saveRDS(adsl, file.path(output_dir, "ADSL.rds"))
saveRDS(adae, file.path(output_dir, "ADAE.rds"))
saveRDS(adlb, file.path(output_dir, "ADLB.rds"))

message("Generated Study ", study_id, " data:")
message("  ADSL: ", nrow(adsl), " subjects")
message("  ADAE: ", nrow(adae), " adverse events")
message("  ADLB: ", nrow(adlb), " lab records")
message("Saved to ", normalizePath(output_dir))
