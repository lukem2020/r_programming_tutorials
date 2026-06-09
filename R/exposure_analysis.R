# S11 Treatment exposure (teal tm_t_exposure / FDA ST&F General).

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
})

# Subject-level exposure summary from ADSL (TRTDURD).
exposure_summary_table <- function(adsl, cfg, arms = NULL) {
  d <- safety_adsl(adsl, cfg) %>% filter_by_arms(., cfg, arms)
  d %>%
    group_by(.data$ARM) %>%
    summarise(
      N = dplyr::n(),
      `Mean duration (days)` = sprintf("%.1f", mean(.data$TRTDURD, na.rm = TRUE)),
      `SD duration` = sprintf("%.1f", stats::sd(.data$TRTDURD, na.rm = TRUE)),
      `Median duration` = sprintf("%.0f", stats::median(.data$TRTDURD, na.rm = TRUE)),
      `Min - Max` = sprintf("%.0f - %.0f",
                            min(.data$TRTDURD, na.rm = TRUE),
                            max(.data$TRTDURD, na.rm = TRUE)),
      .groups = "drop"
    ) %>%
    arrange(.data$ARM) %>%
    rename(Arm = "ARM")
}

# Record-level exposure detail from ADEX.
exposure_detail_table <- function(adex, adsl, cfg, arms = NULL) {
  if (is.null(adex)) {
    return(data.frame(Note = "ADEX not loaded — run programs/01_prepare_adam.R"))
  }
  ids <- safety_subject_ids(adsl, cfg, arms)
  adex %>%
    filter(.data$USUBJID %in% ids) %>%
    with_arm_factor(cfg) %>%
    filter_by_arms(cfg, arms) %>%
    group_by(.data$ARM) %>%
    summarise(
      `Exposure records` = dplyr::n(),
      `Subjects` = dplyr::n_distinct(.data$USUBJID),
      `Mean EXDURD` = if ("EXDURD" %in% names(adex)) {
        sprintf("%.1f", mean(.data$EXDURD, na.rm = TRUE))
      } else {
        "NA"
      },
      `Mean EXDOSE` = if ("EXDOSE" %in% names(adex)) {
        sprintf("%.1f", mean(.data$EXDOSE, na.rm = TRUE))
      } else {
        "NA"
      },
      .groups = "drop"
    ) %>%
    arrange(.data$ARM) %>%
    rename(Arm = "ARM")
}
