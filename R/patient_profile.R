# S9 Patient profile drill-down (TLG IPPG01): demographics, AE timeline, lab trends.

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
})

# Subjects in the safety population, ordered, for the selector.
profile_subject_choices <- function(adsl, cfg) {
  safety_adsl(adsl, cfg) %>%
    arrange(.data$USUBJID) %>%
    pull(.data$USUBJID)
}

# One-row demographic summary for a subject (key/value pairs).
patient_demographics <- function(adsl, usubjid) {
  row <- adsl %>% filter(.data$USUBJID == usubjid)
  if (nrow(row) == 0) return(data.frame(Field = character(), Value = character()))
  data.frame(
    Field = c("USUBJID", "Arm", "Age", "Sex", "Race", "Treatment start", "Treatment end", "End-of-study status"),
    Value = c(
      row$USUBJID[1], as.character(row$ARM[1]), as.character(row$AGE[1]),
      as.character(row$SEX[1]), as.character(row$RACE[1]),
      as.character(row$TRTSDT[1]), as.character(row$TRTEDT[1]),
      as.character(row$EOSSTT[1])
    ),
    stringsAsFactors = FALSE
  )
}

# Chronological treatment-emergent AE timeline for a subject.
patient_ae_timeline <- function(adae, usubjid) {
  adae %>%
    filter(.data$USUBJID == usubjid, .data$TRTEMFL == "Y") %>%
    arrange(.data$ASTDT) %>%
    transmute(
      `Start (study day)` = .data$ASTDY,
      `Preferred Term` = .data$AEDECOD,
      `System Organ Class` = .data$AEBODSYS,
      Severity = .data$AESEV,
      Serious = .data$AESER,
      Outcome = .data$AEOUT
    )
}

# Lab trends for the liver chemistry panel for a subject.
patient_lab_plot <- function(adlb, cfg, usubjid) {
  params <- liver_params(cfg)
  df <- adlb %>%
    filter(.data$USUBJID == usubjid, .data$PARAM %in% params,
           grepl("^Baseline$|^Week", .data$AVISIT), !is.na(.data$AVAL))

  if (nrow(df) == 0) {
    return(
      ggplot() +
        annotate("text", x = 1, y = 1, label = "No liver chemistry records for this subject") +
        theme_void()
    )
  }

  ggplot(df, aes(x = stats::reorder(.data$AVISIT, .data$AVISITN), y = .data$AVAL, group = 1)) +
    geom_line(colour = "#4c9be8", linewidth = 0.8) +
    geom_point(colour = "#4c9be8", size = 2) +
    geom_line(aes(y = .data$ANRHI), linetype = "dashed", colour = "grey50") +
    facet_wrap(~ .data$PARAM, scales = "free_y") +
    labs(
      title = paste0("Liver chemistry over time - ", usubjid),
      subtitle = "Solid = observed value; dashed = upper limit of normal (ULN)",
      x = "Analysis visit", y = "Value"
    ) +
    theme_clinical() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))
}
