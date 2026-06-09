# S3-S5 Adverse event analyses.
# S3 AE Overview (AET01), S4 Serious AEs (AET01 components + AEL03), S5 TEAE by SOC/PT (AET02/AET03).

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(ggplot2)
})

# Treatment-emergent AEs restricted to the safety population, ARM as ordered factor.
.teae <- function(adae, adsl, cfg, arms = NULL) {
  safe_ids <- safety_subject_ids(adsl, cfg, arms)
  adae %>%
    filter(.data$TRTEMFL == "Y", .data$USUBJID %in% safe_ids) %>%
    mutate(ARM = factor(.data$ARM, levels = arm_levels(cfg))) %>%
    filter_by_arms(., cfg, arms)
}

# Severity rank for AET03 worst-grade logic.
.sev_rank <- c(MILD = 1L, MODERATE = 2L, SEVERE = 3L)

# S3 + S4: FDA-style overview of adverse events (subject counts and %).
ae_overview_table <- function(adae, adsl, cfg, arms = NULL) {
  denom <- safety_adsl(adsl, cfg) %>%
    filter_by_arms(., cfg, arms) %>%
    count(.data$ARM, name = "den")
  te <- .teae(adae, adsl, cfg, arms)

  count_subjects <- function(df, label) {
    df %>%
      distinct(.data$ARM, .data$USUBJID) %>%
      count(.data$ARM, name = "n", .drop = FALSE) %>%
      mutate(Category = label)
  }

  # Causality in this study is coded NONE/POSSIBLE/PROBABLE/REMOTE (not Y/N);
  # "related" = any assessment other than NONE.
  rows <- bind_rows(
    count_subjects(te, "Subjects with any TEAE"),
    count_subjects(filter(te, .data$AESER == "Y"), "Subjects with any serious TEAE"),
    count_subjects(filter(te, .data$AESEV == "SEVERE"), "Subjects with any severe TEAE"),
    count_subjects(filter(te, !is.na(.data$AEREL), .data$AEREL != "NONE"),
                   "Subjects with any related TEAE")
  )
  rows$Category <- factor(rows$Category, levels = unique(rows$Category))

  rows %>%
    left_join(denom, by = "ARM") %>%
    mutate(Value = sprintf("%d (%.1f%%)", .data$n, 100 * .data$n / .data$den)) %>%
    select("ARM", "Category", "Value") %>%
    pivot_wider(names_from = "ARM", values_from = "Value", values_fill = "0 (0.0%)") %>%
    arrange(.data$Category) %>%
    rename(`Adverse event category` = "Category")
}

# S4: serious adverse event listing (AEL03 style).
sae_listing <- function(adae, adsl, cfg, arms = NULL) {
  .teae(adae, adsl, cfg, arms) %>%
    filter(.data$AESER == "Y") %>%
    transmute(
      USUBJID = .data$USUBJID,
      Arm = as.character(.data$ARM),
      `Preferred Term` = .data$AEDECOD,
      `System Organ Class` = .data$AEBODSYS,
      Severity = .data$AESEV,
      Outcome = .data$AEOUT
    ) %>%
    arrange(.data$Arm, .data$`Preferred Term`)
}

# S5: subject incidence (%) per arm per preferred term.
teae_incidence <- function(adae, adsl, cfg, arms = NULL) {
  denom <- safety_adsl(adsl, cfg) %>%
    filter_by_arms(., cfg, arms) %>%
    count(.data$ARM, name = "den")
  .teae(adae, adsl, cfg, arms) %>%
    distinct(.data$ARM, .data$USUBJID, .data$AEDECOD) %>%
    count(.data$ARM, .data$AEDECOD, name = "n") %>%
    left_join(denom, by = "ARM") %>%
    mutate(pct = 100 * .data$n / .data$den)
}

# S5: top-N preferred terms by overall subject incidence (same ranking as TEAE bar chart).
teae_top_terms <- function(adae, adsl, cfg, top_n = cfg$display$top_n_ae, arms = NULL) {
  teae_incidence(adae, adsl, cfg, arms) %>%
    group_by(.data$AEDECOD) %>%
    summarise(total = sum(.data$n), .groups = "drop") %>%
    slice_max(.data$total, n = top_n, with_ties = FALSE) %>%
    pull(.data$AEDECOD)
}

# S5 bar chart: top-N preferred terms by overall incidence, plotted by arm.
teae_top_plot <- function(adae, adsl, cfg, top_n = cfg$display$top_n_ae, arms = NULL) {
  inc <- teae_incidence(adae, adsl, cfg, arms)
  top_terms <- teae_top_terms(adae, adsl, cfg, top_n, arms)

  plot_df <- inc %>%
    filter(.data$AEDECOD %in% top_terms) %>%
    mutate(AEDECOD = factor(.data$AEDECOD, levels = rev(top_terms)))

  ggplot(plot_df, aes(x = .data$AEDECOD, y = .data$pct, fill = .data$ARM)) +
    geom_col(position = position_dodge(width = 0.78), width = 0.7) +
    geom_text(aes(label = ifelse(.data$pct >= 2, sprintf("%.0f", .data$pct), "")),
              position = position_dodge(width = 0.78), hjust = -0.25,
              size = 3, colour = "#5b6770") +
    coord_flip(clip = "off") +
    scale_fill_manual(values = arm_palette(cfg)) +
    scale_y_continuous(expand = expansion(mult = c(0, 0.10))) +
    labs(
      title = sprintf("Top %d treatment-emergent adverse events by arm", top_n),
      subtitle = "Subject incidence (%) \u2013 pharmaverse TLG AET02 / FDA ST&F TEAE",
      x = NULL, y = "Subjects with event (%)", fill = "Arm",
      caption = "Treatment-emergent (TRTEMFL == 'Y'), safety population"
    ) +
    theme_clinical() +
    theme(panel.grid.major.y = element_blank())
}

# S5 table: SOC -> PT subject incidence, counts by arm.
soc_pt_table <- function(adae, adsl, cfg, arms = NULL) {
  .teae(adae, adsl, cfg, arms) %>%
    distinct(.data$ARM, .data$USUBJID, .data$AEBODSYS, .data$AEDECOD) %>%
    count(.data$ARM, .data$AEBODSYS, .data$AEDECOD, name = "n") %>%
    pivot_wider(names_from = "ARM", values_from = "n", values_fill = 0) %>%
    arrange(.data$AEBODSYS, .data$AEDECOD) %>%
    rename(`System Organ Class` = "AEBODSYS", `Preferred Term` = "AEDECOD")
}

# S5b: TEAE by SOC, PT and worst severity per subject (AET03 / tm_t_events_by_grade).
teae_severity_table <- function(adae, adsl, cfg, arms = NULL) {
  denom <- safety_adsl(adsl, cfg) %>%
    filter_by_arms(., cfg, arms) %>%
    count(.data$ARM, name = "den")

  worst <- .teae(adae, adsl, cfg, arms) %>%
    filter(!is.na(.data$AESEV), .data$AESEV %in% names(.sev_rank)) %>%
    mutate(sev_rk = .sev_rank[.data$AESEV]) %>%
    group_by(.data$ARM, .data$USUBJID, .data$AEBODSYS, .data$AEDECOD) %>%
    summarise(worst_sev = names(.sev_rank)[max(.data$sev_rk, na.rm = TRUE)],
              .groups = "drop")

  sev_levels <- names(.sev_rank)
  arms_present <- intersect(arm_levels(cfg), unique(as.character(worst$ARM)))

  rows <- worst %>%
    distinct(.data$ARM, .data$AEBODSYS, .data$AEDECOD, .data$worst_sev) %>%
    count(.data$ARM, .data$AEBODSYS, .data$AEDECOD, .data$worst_sev, name = "n") %>%
    left_join(denom, by = "ARM") %>%
    mutate(Value = sprintf("%d (%.1f%%)", .data$n, 100 * .data$n / .data$den)) %>%
    select("ARM", "AEBODSYS", "AEDECOD", "worst_sev", "Value")

  out <- rows %>%
    pivot_wider(
      names_from = c("ARM", "worst_sev"),
      values_from = "Value",
      values_fill = "0 (0.0%)"
    ) %>%
    arrange(.data$AEBODSYS, .data$AEDECOD) %>%
    rename(`System Organ Class` = "AEBODSYS", `Preferred Term` = "AEDECOD")

  out
}
