# Clinical data preparation helpers for MDR and safety review
# Source from tutorials or app with: source("R/data_prep.R")

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
})

#' Load simulated ADaM datasets
load_study_data <- function(data_dir = file.path("data", "simulated")) {
  list(
    ADSL = readRDS(file.path(data_dir, "ADSL.rds")),
    ADAE = readRDS(file.path(data_dir, "ADAE.rds")),
    ADLB = readRDS(file.path(data_dir, "ADLB.rds"))
  )
}

#' Join subject-level flags onto event datasets
attach_subject_flags <- function(adsl, data) {
  subject_cols <- adsl %>%
    select(USUBJID, ARM, ARMCD, SEX, RACE, SAFFL, ITTFL, AGE)

  data %>%
    left_join(subject_cols, by = "USUBJID")
}

#' Treatment-emergent AE counts by treatment arm and preferred term
summarize_teae_by_arm <- function(adae, adsl) {
  adae %>%
    attach_subject_flags(adsl) %>%
    filter(TRTEMFL == "Y") %>%
    count(ARM, AEDECOD, AESEV, name = "n_events") %>%
    group_by(ARM, AEDECOD) %>%
    summarise(
      total_events = sum(n_events),
      severe_events = sum(n_events[AESEV == "SEVERE"]),
      .groups = "drop"
    ) %>%
    arrange(ARM, desc(total_events))
}

#' Subject-level TEAE incidence (for safety signal tables)
teae_incidence_by_arm <- function(adae, adsl) {
  adae %>%
    attach_subject_flags(adsl) %>%
    filter(TRTEMFL == "Y") %>%
    distinct(USUBJID, ARM, AEDECOD) %>%
    count(ARM, AEDECOD, name = "n_subjects") %>%
    left_join(
      adsl %>% count(ARM, name = "n_arm"),
      by = "ARM"
    ) %>%
    mutate(pct = round(100 * n_subjects / n_arm, 1)) %>%
    arrange(ARM, desc(pct))
}

#' Lab shift table: baseline normal -> post-baseline abnormal
summarize_lab_shifts <- function(adlb, adsl) {
  baseline <- adlb %>%
    filter(ABLFL == "Y") %>%
    select(USUBJID, PARAMCD, baseline_flag = ANRIND)

  post <- adlb %>%
    filter(ABLFL != "Y") %>%
    group_by(USUBJID, PARAMCD) %>%
    slice_max(order_by = ADY, n = 1, with_ties = FALSE) %>%
    ungroup() %>%
    select(USUBJID, PARAMCD, PARAM, post_flag = ANRIND)

  post %>%
    left_join(baseline, by = c("USUBJID", "PARAMCD")) %>%
    attach_subject_flags(adsl) %>%
    mutate(
      shift = paste(baseline_flag, "to", post_flag),
      shift_flag = baseline_flag == "NORMAL" & post_flag %in% c("LOW", "HIGH")
    ) %>%
    group_by(ARM, PARAM, shift) %>%
    summarise(n = n(), .groups = "drop") %>%
    arrange(ARM, PARAM, desc(n))
}

#' Safety population filter (CtQ: subject eligibility / analysis population)
filter_safety_population <- function(adsl) {
  adsl %>% filter(SAFFL == "Y")
}

#' Example patient profile slice for MDR drill-down
patient_profile <- function(usubjid, adsl, adae, adlb) {
  list(
    demographics = adsl %>% filter(USUBJID == usubjid),
    adverse_events = adae %>%
      filter(USUBJID == usubjid) %>%
      arrange(AESTDTC),
    labs = adlb %>%
      filter(USUBJID == usubjid) %>%
      arrange(PARAMCD, ADY)
  )
}
