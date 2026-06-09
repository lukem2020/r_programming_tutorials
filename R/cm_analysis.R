# S13 Concomitant medications (teal CM module / CM01).

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
})

.on_treatment_cm <- function(adcm, cfg) {
  flag <- cfg$cm_review$on_treatment_flag
  if (!flag %in% names(adcm)) return(adcm)
  adcm %>% filter(.data[[flag]] == "Y")
}

# Summary: n (%) subjects with any on-treatment CM by arm; top CMDECOD terms.
cm_summary_table <- function(adcm, adsl, cfg, arms = NULL, top_n = cfg$display$top_n_cm) {
  if (is.null(adcm)) {
    return(data.frame(Note = "ADCM not loaded — run programs/01_prepare_adam.R"))
  }
  ids <- safety_subject_ids(adsl, cfg, arms)
  denom <- safety_adsl(adsl, cfg) %>%
    filter_by_arms(., cfg, arms) %>%
    count(.data$ARM, name = "den")

  cm <- .on_treatment_cm(adcm, cfg) %>%
    filter(.data$USUBJID %in% ids) %>%
    with_arm_factor(cfg) %>%
    filter_by_arms(., cfg, arms)

  any_row <- cm %>%
    distinct(.data$ARM, .data$USUBJID) %>%
    count(.data$ARM, name = "n") %>%
    left_join(denom, by = "ARM") %>%
    transmute(
      `Medication term` = "Subjects with any on-treatment CM",
      ARM = .data$ARM,
      Value = sprintf("%d (%.1f%%)", .data$n, 100 * .data$n / .data$den)
    )

  top_terms <- cm %>%
    count(.data$CMDECOD, sort = TRUE) %>%
    slice_head(n = top_n) %>%
    pull(.data$CMDECOD)

  term_rows <- cm %>%
    filter(.data$CMDECOD %in% top_terms) %>%
    distinct(.data$ARM, .data$USUBJID, .data$CMDECOD) %>%
    count(.data$ARM, .data$CMDECOD, name = "n") %>%
    left_join(denom, by = "ARM") %>%
    transmute(
      `Medication term` = .data$CMDECOD,
      ARM = .data$ARM,
      Value = sprintf("%d (%.1f%%)", .data$n, 100 * .data$n / .data$den)
    )

  bind_rows(any_row, term_rows) %>%
    pivot_wider(names_from = "ARM", values_from = "Value", values_fill = "0 (0.0%)") %>%
    arrange(.data$`Medication term`)
}

cm_listing <- function(adcm, adsl, cfg, arms = NULL) {
  if (is.null(adcm)) {
    return(data.frame(Note = "ADCM not loaded"))
  }
  ids <- safety_subject_ids(adsl, cfg, arms)
  .on_treatment_cm(adcm, cfg) %>%
    filter(.data$USUBJID %in% ids) %>%
    with_arm_factor(cfg) %>%
    filter_by_arms(., cfg, arms) %>%
    transmute(
      USUBJID = .data$USUBJID,
      Arm = as.character(.data$ARM),
      `Reported term` = .data$CMTRT,
      `Preferred term` = .data$CMDECOD,
      `Start (study day)` = .data$ASTDY,
      `End (study day)` = .data$AENDY
    ) %>%
    arrange(.data$Arm, .data$USUBJID, .data$`Preferred term`)
}
