# S6-S8 Laboratory analyses.
# S6 central tendency (LBT01/LTG01), S7 shift table (LBT04), S8 Hy's Law eDISH (LBT09-11 + eDISH plot).

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(ggplot2)
})

# Liver chemistry parameter labels from config.
liver_params <- function(cfg) {
  hl <- cfg$hepatic_safety$hys_law
  c(ALT = hl$alt_param, AST = hl$ast_param, Bilirubin = hl$bili_param)
}

# S6: mean (+/- SD) by arm over scheduled visits for a chosen parameter.
lab_central_tendency <- function(adlb, cfg, param) {
  adlb %>%
    with_arm_factor(cfg) %>%
    filter(!is.na(.data$ARM), .data$PARAM == param,
           grepl("^Baseline$|^Week", .data$AVISIT), !is.na(.data$AVAL)) %>%
    group_by(.data$ARM, .data$AVISIT, .data$AVISITN) %>%
    summarise(mean = mean(.data$AVAL), sd = sd(.data$AVAL), n = dplyr::n(), .groups = "drop") %>%
    arrange(.data$AVISITN)
}

lab_central_tendency_plot <- function(adlb, cfg, param) {
  df <- lab_central_tendency(adlb, cfg, param)
  uln <- adlb %>% filter(.data$PARAM == param, !is.na(.data$ANRHI)) %>%
    summarise(u = stats::median(.data$ANRHI)) %>% pull(.data$u)

  p <- ggplot(df, aes(x = stats::reorder(.data$AVISIT, .data$AVISITN),
                      y = .data$mean, colour = .data$ARM, group = .data$ARM)) +
    geom_line(linewidth = 0.9) +
    geom_point(size = 2) +
    scale_colour_manual(values = arm_palette(cfg)) +
    labs(
      title = paste0("Mean ", param, " over time by arm"),
      subtitle = "Laboratory central tendency - pharmaverse TLG LBT01 / LTG01",
      x = "Analysis visit", y = paste0("Mean ", param), colour = "Arm"
    ) +
    theme_clinical() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))

  if (length(uln) == 1 && is.finite(uln)) {
    p <- p + geom_hline(yintercept = uln, linetype = "dashed", colour = "grey40") +
      annotate("text", x = 1, y = uln, label = "ULN", vjust = -0.5,
               hjust = 0, size = 3, colour = "grey40")
  }
  p
}

# S7: shift table - baseline (BNRIND) vs worst post-baseline (ANRIND) per subject.
# Severity rank: NORMAL < LOW < HIGH; "worst" = highest rank observed post-baseline.
lab_shift_table <- function(adlb, cfg, param) {
  worst_rank <- c(NORMAL = 0L, LOW = 1L, HIGH = 2L)
  rank_name <- names(worst_rank)

  adlb %>%
    with_arm_factor(cfg) %>%
    filter(!is.na(.data$ARM), .data$PARAM == param,
           (is.na(.data$ABLFL) | .data$ABLFL != "Y"),
           grepl("^Week", .data$AVISIT),
           !is.na(.data$ANRIND), !is.na(.data$BNRIND)) %>%
    mutate(rk = worst_rank[.data$ANRIND]) %>%
    group_by(.data$USUBJID, .data$ARM, .data$BNRIND) %>%
    summarise(worst_rk = max(.data$rk, na.rm = TRUE), .groups = "drop") %>%
    mutate(
      worst = rank_name[.data$worst_rk + 1L],
      Shift = paste0("Baseline ", tools::toTitleCase(tolower(.data$BNRIND)),
                     " -> Post-baseline ", tools::toTitleCase(tolower(.data$worst)))
    ) %>%
    count(.data$ARM, .data$Shift, name = "n") %>%
    pivot_wider(names_from = "ARM", values_from = "n", values_fill = 0) %>%
    arrange(.data$Shift)
}

# S8: per-subject max post-baseline ALT/ULN and Bilirubin/ULN for the eDISH scatter.
hys_law_data <- function(adlb, cfg) {
  hl <- cfg$hepatic_safety$hys_law
  pb <- adlb %>%
    with_arm_factor(cfg) %>%
    filter(!is.na(.data$ARM),
           (is.na(.data$ABLFL) | .data$ABLFL != "Y"),
           grepl("^Week", .data$AVISIT),
           !is.na(.data$AVAL), !is.na(.data$ANRHI), .data$ANRHI > 0) %>%
    mutate(ratio = .data$AVAL / .data$ANRHI)

  alt <- pb %>% filter(.data$PARAM == hl$alt_param) %>%
    group_by(.data$USUBJID, .data$ARM) %>%
    summarise(alt_uln = max(.data$ratio, na.rm = TRUE), .groups = "drop")
  bili <- pb %>% filter(.data$PARAM == hl$bili_param) %>%
    group_by(.data$USUBJID) %>%
    summarise(bili_uln = max(.data$ratio, na.rm = TRUE), .groups = "drop")

  alt %>%
    inner_join(bili, by = "USUBJID") %>%
    mutate(potential_hys_law = .data$alt_uln >= hl$alt_threshold_x_uln &
                               .data$bili_uln >= hl$bili_threshold_x_uln)
}

hys_law_plot <- function(adlb, cfg) {
  hl <- cfg$hepatic_safety$hys_law
  df <- hys_law_data(adlb, cfg)
  xt <- hl$alt_threshold_x_uln
  yt <- hl$bili_threshold_x_uln

  ggplot(df, aes(x = .data$alt_uln, y = .data$bili_uln, colour = .data$ARM)) +
    geom_vline(xintercept = xt, linetype = "dashed", colour = "grey40") +
    geom_hline(yintercept = yt, linetype = "dashed", colour = "grey40") +
    geom_point(size = 2.4, alpha = 0.8) +
    scale_x_log10() +
    scale_y_log10() +
    scale_colour_manual(values = arm_palette(cfg)) +
    labs(
      title = "Hy's Law / eDISH screening plot",
      subtitle = sprintf("Max post-baseline ALT vs Bilirubin (x ULN); Hy's Law zone: ALT >= %gx and Bilirubin >= %gx", xt, yt),
      x = "Max post-baseline ALT (x ULN, log scale)",
      y = "Max post-baseline Bilirubin (x ULN, log scale)",
      colour = "Arm",
      caption = "FDA DILI screen using maximum post-baseline values"
    ) +
    theme_clinical()
}
