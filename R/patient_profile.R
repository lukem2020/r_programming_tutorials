# S9 Patient profile drill-down (TLG IPPG01): demographics, AE timeline, labs, vitals, CM, MH.

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
})

# Subjects in the safety population, ordered, for the selector.
profile_subject_choices <- function(adsl, cfg, completed_only = FALSE) {
  d <- safety_adsl(adsl, cfg)
  if (isTRUE(completed_only)) {
    pp <- cfg$patient_profile
    d <- d %>% filter(.data[[pp$disposition_variable]] == pp$completed_eosstt)
  }
  d %>%
    arrange(.data$USUBJID) %>%
    pull(.data$USUBJID)
}

# One-row demographic summary for a subject (key/value pairs).
patient_demographics <- function(adsl, usubjid) {
  row <- adsl %>% filter(.data$USUBJID == usubjid)
  if (nrow(row) == 0) return(data.frame(Field = character(), Value = character()))
  data.frame(
    Field = c("USUBJID", "Arm", "Age", "Sex", "Race",
              "Treatment start", "Treatment end", "Treatment duration (days)",
              "End-of-study status"),
    Value = c(
      row$USUBJID[1], as.character(row$ARM[1]), as.character(row$AGE[1]),
      as.character(row$SEX[1]), as.character(row$RACE[1]),
      as.character(row$TRTSDT[1]), as.character(row$TRTEDT[1]),
      as.character(row$TRTDURD[1]),
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

# Panel definitions for patient-profile lab trend plots (IPPG01-style).
patient_lab_panel_specs <- function(cfg) {
  hepatic <- unname(liver_params(cfg))
  list(
    list(id = "hepatic", title = "Hepatic panel", params = hepatic),
    list(
      id = "chemistry", title = "Chemistry panel",
      lbcat = "CHEMISTRY", exclude = hepatic
    ),
    list(id = "hematology", title = "Haematology panel", lbcat = "HEMATOLOGY"),
    list(id = "urinalysis", title = "Urinalysis panel", lbcat = "URINALYSIS")
  )
}

.pp_profile_excluded_lbcat <- function(cfg) {
  excl <- cfg$patient_profile$exclude_lbcat
  if (is.null(excl)) character() else unlist(excl, use.names = FALSE)
}

.pp_profile_apply_lbcat_exclusions <- function(df, cfg) {
  excl <- .pp_profile_excluded_lbcat(cfg)
  if (length(excl) == 0L || !"LBCAT" %in% names(df)) return(df)
  df %>% filter(is.na(.data$LBCAT) | !(.data$LBCAT %in% excl))
}

.patient_lab_panel_rows <- function(adlb, cfg, usubjid, spec) {
  df <- adlb %>%
    filter(
      .data$USUBJID == usubjid,
      grepl("^Baseline$|^Week", .data$AVISIT),
      !is.na(.data$AVAL)
    ) %>%
    .pp_profile_apply_lbcat_exclusions(., cfg)

  if (!is.null(spec$params)) {
    df <- df %>% filter(.data$PARAM %in% spec$params)
  } else if (!is.null(spec$lbcat)) {
    df <- df %>% filter(.data$LBCAT == spec$lbcat)
  }

  if (!is.null(spec$exclude) && length(spec$exclude) > 0) {
    df <- df %>% filter(!(.data$PARAM %in% spec$exclude))
  }

  if (nrow(df) > 0L) {
    df <- mean_by_visit(
      df, c("USUBJID", "PARAM", "AVISIT", "AVISITN"), c("AVAL", "ANRHI")
    )
  }

  df
}

patient_lab_panel_n_params <- function(adlb, cfg, usubjid, spec) {
  .patient_lab_panel_rows(adlb, cfg, usubjid, spec) %>%
    distinct(.data$PARAM) %>%
    nrow()
}

# Panels that have numeric trend data for this subject.
patient_lab_panels_for_subject <- function(adlb, cfg, usubjid) {
  specs <- patient_lab_panel_specs(cfg)
  out <- list()
  for (spec in specs) {
    n <- patient_lab_panel_n_params(adlb, cfg, usubjid, spec)
    if (n > 0L) {
      spec$n_params <- n
      out <- c(out, list(spec))
    }
  }
  out
}

patient_lab_panel_height <- function(n_params, ncol = 3L) {
  max(200L, 90L + ceiling(n_params / ncol) * 175L)
}

# Faceted trend plot for one laboratory panel (all params in the panel).
patient_lab_panel_trend_plot <- function(adlb, cfg, usubjid, spec) {
  df_all <- .patient_lab_panel_rows(adlb, cfg, usubjid, spec)
  if (nrow(df_all) == 0) {
    return(
      ggplot() +
        annotate("text", x = 1, y = 1,
                 label = paste0("No records for ", spec$title)) +
        theme_void()
    )
  }

  df_fit <- lm_fit_data(df_all, y_var = "AVAL", group_vars = "PARAM")
  n_facet <- dplyr::n_distinct(df_all$PARAM)
  ncol <- min(3L, n_facet)

  ggplot(df_all, aes(x = .data$AVISITN, y = .data$AVAL, group = 1)) +
    geom_point(colour = "#4c9be8", size = 1.8) +
    geom_lm_trend(data = df_fit, colour = "#4c9be8") +
    geom_line(aes(y = .data$ANRHI), linetype = "dashed", colour = "grey50") +
    facet_wrap(~ .data$PARAM, scales = "free_y", ncol = ncol) +
    visit_axis_scale(df_all) +
    labs(
      title = paste0(spec$title, " \u2014 ", usubjid),
      subtitle = "All scheduled visits shown; linear fit excludes statistical outliers",
      x = "Analysis visit", y = "Value"
    ) +
    theme_clinical() +
    theme(
      axis.text.x = element_text(angle = 45, hjust = 1, size = 7),
      strip.text = element_text(size = 8)
    )
}

# All laboratory results for one subject (long listing for drill-down).
patient_lab_table <- function(adlb, cfg, usubjid) {
  out <- adlb %>%
    filter(.data$USUBJID == usubjid) %>%
    .pp_profile_apply_lbcat_exclusions(., cfg) %>%
    filter(!is.na(.data$AVAL) | (!is.na(.data$AVALC) & nzchar(.data$AVALC))) %>%
    mutate(
      category = dplyr::coalesce(.data$LBCAT, "UNCATEGORIZED"),
      result = dplyr::if_else(!is.na(.data$AVAL), as.character(.data$AVAL), .data$AVALC)
    ) %>%
    arrange(.data$category, .data$PARAM, .data$AVISITN) %>%
    transmute(
      Category = .data$category,
      Parameter = .data$PARAM,
      `Analysis visit` = .data$AVISIT,
      `Study day` = .data$ADY,
      Result = .data$result,
      Unit = .data$LBSTRESU,
      `Change from baseline` = dplyr::if_else(
        !is.na(.data$CHG), round(.data$CHG, 2), NA_real_
      ),
      `Baseline range` = .data$BNRIND,
      `Visit range` = .data$ANRIND,
      Baseline = .data$ABLFL
    )

  if (nrow(out) == 0) {
    return(data.frame(Note = "No laboratory results for this subject"))
  }
  out
}

patient_vitals_panel_n_params <- function(advs, usubjid) {
  if (is.null(advs)) return(0L)
  advs %>%
    filter(
      .data$USUBJID == usubjid,
      grepl("^Baseline$|^Week", .data$AVISIT),
      !is.na(.data$AVAL)
    ) %>%
    distinct(.data$PARAM) %>%
    nrow()
}

patient_vitals_panel_height <- function(n_params, ncol = 3L) {
  max(200L, 90L + ceiling(n_params / ncol) * 175L)
}

# All trend-plottable vital signs for one subject (faceted panel).
patient_vitals_panel_plot <- function(advs, usubjid) {
  if (is.null(advs)) {
    return(ggplot() + annotate("text", x = 1, y = 1, label = "ADVS not loaded") + theme_void())
  }

  param_order <- vs_trend_params(advs)
  df_all <- advs %>%
    filter(
      .data$USUBJID == usubjid,
      .data$PARAM %in% param_order,
      grepl("^Baseline$|^Week", .data$AVISIT),
      !is.na(.data$AVAL)
    ) %>%
    mean_by_visit(., c("USUBJID", "PARAM", "AVISIT", "AVISITN"), "AVAL") %>%
    mutate(PARAM = factor(.data$PARAM, levels = param_order))

  if (nrow(df_all) == 0) {
    return(ggplot() +
             annotate("text", x = 1, y = 1, label = "No vital sign records for this subject") +
             theme_void())
  }

  df_fit <- lm_fit_data(df_all, y_var = "AVAL", group_vars = "PARAM")
  n_facet <- dplyr::n_distinct(df_all$PARAM)
  ncol <- min(3L, n_facet)

  ggplot(df_all, aes(x = .data$AVISITN, y = .data$AVAL, group = 1)) +
    geom_point(colour = "#4c9be8", size = 1.8) +
    geom_lm_trend(data = df_fit, colour = "#4c9be8") +
    facet_wrap(~ .data$PARAM, scales = "free_y", ncol = ncol) +
    visit_axis_scale(df_all) +
    labs(
      title = paste0("Vital signs \u2014 ", usubjid),
      subtitle = "All scheduled visits shown; linear fit excludes statistical outliers",
      x = "Analysis visit", y = "Value"
    ) +
    theme_clinical() +
    theme(
      axis.text.x = element_text(angle = 45, hjust = 1, size = 7),
      strip.text = element_text(size = 8)
    )
}

# On-treatment concomitant medications for one subject.
patient_cm_table <- function(adcm, cfg, usubjid) {
  if (is.null(adcm)) {
    return(data.frame(Note = "ADCM not loaded"))
  }
  flag <- cfg$cm_review$on_treatment_flag
  adcm %>%
    filter(.data$USUBJID == usubjid) %>%
    { if (flag %in% names(.)) filter(., .data[[flag]] == "Y") else . } %>%
    arrange(.data$ASTDY) %>%
    transmute(
      `Reported term` = .data$CMTRT,
      `Preferred term` = .data$CMDECOD,
      `Start (study day)` = .data$ASTDY,
      `End (study day)` = .data$AENDY
    )
}

# Medical history for one subject.
patient_mh_table <- function(admh, usubjid) {
  if (is.null(admh)) {
    return(data.frame(Note = "ADMH not loaded"))
  }
  admh %>%
    filter(.data$USUBJID == usubjid) %>%
    arrange(.data$MHTERM) %>%
    transmute(
      `Medical term` = .data$MHTERM,
      `Body system` = if ("MHBODSYS" %in% names(admh)) .data$MHBODSYS else NA_character_,
      `Start (study day)` = if ("MHSTDY" %in% names(admh)) .data$MHSTDY else NA_real_
    )
}
