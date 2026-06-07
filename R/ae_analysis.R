# S3-S5 Adverse event analyses.
# S3 AE Overview (AET01), S4 Serious AEs (AET01 components + AEL03), S5 TEAE by SOC/PT (AET02/AET03).

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(ggplot2)
})

# Treatment-emergent AEs restricted to the safety population, ARM as ordered factor.
.teae <- function(adae, adsl, cfg) {
  safe_ids <- safety_adsl(adsl, cfg)$USUBJID
  adae %>%
    filter(.data$TRTEMFL == "Y", .data$USUBJID %in% safe_ids) %>%
    mutate(ARM = factor(.data$ARM, levels = arm_levels(cfg)))
}

# S3 + S4: FDA-style overview of adverse events (subject counts and %).
ae_overview_table <- function(adae, adsl, cfg) {
  denom <- safety_adsl(adsl, cfg) %>% count(.data$ARM, name = "den")
  te <- .teae(adae, adsl, cfg)

  count_subjects <- function(df, label) {
    df %>%
      distinct(.data$ARM, .data$USUBJID) %>%
      count(.data$ARM, name = "n", .drop = FALSE) %>%
      mutate(Category = label)
  }

  rows <- bind_rows(
    count_subjects(te, "Subjects with any TEAE"),
    count_subjects(filter(te, .data$AESER == "Y"), "Subjects with any serious TEAE"),
    count_subjects(filter(te, .data$AESEV == "SEVERE"), "Subjects with any severe TEAE"),
    count_subjects(filter(te, .data$AEREL == "Y"), "Subjects with any related TEAE")
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
sae_listing <- function(adae, adsl, cfg) {
  .teae(adae, adsl, cfg) %>%
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
teae_incidence <- function(adae, adsl, cfg) {
  denom <- safety_adsl(adsl, cfg) %>% count(.data$ARM, name = "den")
  .teae(adae, adsl, cfg) %>%
    distinct(.data$ARM, .data$USUBJID, .data$AEDECOD) %>%
    count(.data$ARM, .data$AEDECOD, name = "n") %>%
    left_join(denom, by = "ARM") %>%
    mutate(pct = 100 * .data$n / .data$den)
}

# S5 bar chart: top-N preferred terms by overall incidence, plotted by arm.
teae_top_plot <- function(adae, adsl, cfg, top_n = cfg$display$top_n_ae) {
  inc <- teae_incidence(adae, adsl, cfg)
  top_terms <- inc %>%
    group_by(.data$AEDECOD) %>%
    summarise(total = sum(.data$n), .groups = "drop") %>%
    slice_max(.data$total, n = top_n, with_ties = FALSE) %>%
    pull(.data$AEDECOD)

  plot_df <- inc %>%
    filter(.data$AEDECOD %in% top_terms) %>%
    mutate(AEDECOD = factor(.data$AEDECOD, levels = rev(top_terms)))

  ggplot(plot_df, aes(x = .data$AEDECOD, y = .data$pct, fill = .data$ARM)) +
    geom_col(position = position_dodge(width = 0.8), width = 0.7) +
    coord_flip() +
    scale_fill_manual(values = arm_palette(cfg)) +
    labs(
      title = sprintf("Top %d treatment-emergent adverse events by arm", top_n),
      subtitle = "Subject incidence (%) - pharmaverse TLG AET02 / FDA ST&F TEAE",
      x = NULL, y = "Subjects with event (%)", fill = "Arm",
      caption = "Treatment-emergent (TRTEMFL == 'Y'), safety population"
    ) +
    theme_clinical()
}

# S5 table: SOC -> PT subject incidence, counts by arm.
soc_pt_table <- function(adae, adsl, cfg) {
  .teae(adae, adsl, cfg) %>%
    distinct(.data$ARM, .data$USUBJID, .data$AEBODSYS, .data$AEDECOD) %>%
    count(.data$ARM, .data$AEBODSYS, .data$AEDECOD, name = "n") %>%
    pivot_wider(names_from = "ARM", values_from = "n", values_fill = 0) %>%
    arrange(.data$AEBODSYS, .data$AEDECOD) %>%
    rename(`System Organ Class` = "AEBODSYS", `Preferred Term` = "AEDECOD")
}
