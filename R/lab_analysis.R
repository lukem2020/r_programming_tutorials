# S6-S8 Laboratory analyses.
# S6 central tendency (LBT01/LTG01), S7 shift table (LBT04), S8 Hy's Law eDISH (LBT09-11 + eDISH plot).

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(ggplot2)
})

# Hepatic panel for Hy's Law / eDISH (S8) — fixed trio from config.
liver_params <- function(cfg) {
  hl <- cfg$hepatic_safety$hys_law
  c(ALT = hl$alt_param, AST = hl$ast_param, Bilirubin = hl$bili_param)
}

# Full ADLB catalogue: all PARAM values grouped by LBCAT for selectInput optgroups.
lab_param_catalog <- function(adlb) {
  # One entry per PARAMCD (ADLB may repeat PARAMCD under multiple LBCAT values).
  catalog <- adlb %>%
    filter(!is.na(.data$PARAM), nzchar(.data$PARAM), !is.na(.data$PARAMCD)) %>%
    distinct(.data$PARAM, .data$PARAMCD, .data$LBCAT) %>%
    mutate(category = dplyr::coalesce(.data$LBCAT, "UNCATEGORIZED")) %>%
    arrange(.data$PARAMCD, is.na(.data$LBCAT)) %>%
    distinct(.data$PARAMCD, .keep_all = TRUE) %>%
    arrange(.data$category, .data$PARAM)

  label <- sprintf("%s (%s)", catalog$PARAM, catalog$PARAMCD)
  by_category <- split(setNames(catalog$PARAM, label), catalog$category)

  shift_ok <- adlb %>%
    filter(grepl("^Week", .data$AVISIT),
           !is.na(.data$BNRIND), !is.na(.data$ANRIND),
           is.na(.data$ABLFL) | .data$ABLFL != "Y") %>%
    distinct(.data$PARAM) %>%
    pull(.data$PARAM)

  shift_by_category <- lapply(by_category, function(g) {
    g[unname(g) %in% shift_ok]
  })
  shift_by_category <- shift_by_category[lengths(shift_by_category) > 0]

  list(
    by_category = by_category,
    shift_by_category = shift_by_category,
    default_param = catalog$PARAM[catalog$PARAMCD == "ALT"][1]
  )
}

default_lab_param <- function(cfg, catalog) {
  alt <- cfg$hepatic_safety$hys_law$alt_param
  if (!is.null(catalog$default_param) && alt %in% unlist(catalog$by_category)) alt
  else unlist(catalog$by_category)[[1]]
}

# S6: mean (+/- SD) by arm over scheduled visits for a chosen parameter.
lab_central_tendency <- function(adlb, cfg, param, arms = NULL) {
  adlb %>%
    with_arm_factor(cfg) %>%
    filter_by_arms(., cfg, arms) %>%
    filter(!is.na(.data$ARM), .data$PARAM == param,
           grepl("^Baseline$|^Week", .data$AVISIT), !is.na(.data$AVAL)) %>%
    mean_by_visit(., c("USUBJID", "ARM", "AVISIT", "AVISITN"), "AVAL") %>%
    group_by(.data$ARM, .data$AVISIT, .data$AVISITN) %>%
    summarise(mean = mean(.data$AVAL), sd = sd(.data$AVAL), n = dplyr::n(), .groups = "drop") %>%
    arrange(.data$AVISITN)
}

# S6 (change): mean CHG from baseline over visits.
lab_change_from_baseline <- function(adlb, cfg, param, arms = NULL) {
  adlb %>%
    with_arm_factor(cfg) %>%
    filter_by_arms(., cfg, arms) %>%
    filter(!is.na(.data$ARM), .data$PARAM == param,
           grepl("^Week", .data$AVISIT), !is.na(.data$CHG)) %>%
    mean_by_visit(., c("USUBJID", "ARM", "AVISIT", "AVISITN"), "CHG") %>%
    group_by(.data$ARM, .data$AVISIT, .data$AVISITN) %>%
    summarise(mean = mean(.data$CHG), sd = sd(.data$CHG), n = dplyr::n(), .groups = "drop") %>%
    arrange(.data$AVISITN)
}

lab_change_from_baseline_plot <- function(adlb, cfg, param, arms = NULL) {
  df_all <- lab_change_from_baseline(adlb, cfg, param, arms)
  if (nrow(df_all) == 0) {
    return(
      ggplot() +
        annotate("text", x = 1, y = 1,
                 label = "No change-from-baseline data for this parameter") +
        theme_void()
    )
  }
  df_fit <- lm_fit_data(df_all, y_var = "mean", group_vars = "ARM")
  dodge <- position_dodge(width = 0.35)
  ggplot(df_all, aes(x = .data$AVISITN, y = .data$mean, colour = .data$ARM, group = .data$ARM)) +
    geom_hline(yintercept = 0, linetype = "dashed", colour = "grey40") +
    geom_errorbar(aes(ymin = .data$mean - .data$sd, ymax = .data$mean + .data$sd),
                  width = 0.18, linewidth = 0.5, alpha = 0.55, position = dodge) +
    geom_point(size = 2.4, position = dodge) +
    geom_lm_trend(data = df_fit, position = dodge) +
    scale_colour_manual(values = arm_palette(cfg)) +
    visit_axis_scale(df_all) +
    labs(
      title = paste0("Mean change from baseline — ", param),
      subtitle = "All scheduled visits shown; linear fit excludes statistical outliers",
      x = "Analysis visit", y = "Mean change from baseline", colour = "Arm",
      caption = "Points = all scheduled visits; regression uses non-outlier visits only (IQR + studentized residuals)"
    ) +
    theme_clinical() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))
}

lab_central_tendency_plot <- function(adlb, cfg, param, arms = NULL) {
  df_all <- lab_central_tendency(adlb, cfg, param, arms)
  if (nrow(df_all) == 0) {
    return(
      ggplot() +
        annotate("text", x = 1, y = 1,
                 label = "No numeric lab data for this parameter at scheduled visits") +
        theme_void()
    )
  }
  uln <- adlb %>% filter(.data$PARAM == param, !is.na(.data$ANRHI)) %>%
    summarise(u = stats::median(.data$ANRHI)) %>% pull(.data$u)

  df_fit <- lm_fit_data(df_all, y_var = "mean", group_vars = "ARM")
  dodge <- position_dodge(width = 0.35)
  p <- ggplot(df_all, aes(x = .data$AVISITN, y = .data$mean, colour = .data$ARM, group = .data$ARM)) +
    geom_errorbar(aes(ymin = .data$mean - .data$sd, ymax = .data$mean + .data$sd),
                  width = 0.18, linewidth = 0.5, alpha = 0.55, position = dodge) +
    geom_point(size = 2.4, position = dodge) +
    geom_lm_trend(data = df_fit, position = dodge) +
    scale_colour_manual(values = arm_palette(cfg)) +
    visit_axis_scale(df_all) +
    labs(
      title = paste0("Mean ", param, " over time by arm"),
      subtitle = "All scheduled visits shown; linear fit excludes statistical outliers",
      x = "Analysis visit", y = paste0("Mean ", param), colour = "Arm",
      caption = "Points = all scheduled visits; regression uses non-outlier visits only; dashed line = ULN"
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
lab_shift_table <- function(adlb, cfg, param, arms = NULL) {
  worst_rank <- c(NORMAL = 0L, LOW = 1L, HIGH = 2L)
  rank_name <- names(worst_rank)

  out <- adlb %>%
    with_arm_factor(cfg) %>%
    filter_by_arms(., cfg, arms) %>%
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

  if (nrow(out) == 0) {
    return(data.frame(Note = "No shift data (BNRIND/ANRIND) for this parameter"))
  }
  out
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

  flagged <- df %>% filter(.data$potential_hys_law)

  ggplot(df, aes(x = .data$alt_uln, y = .data$bili_uln)) +
    annotate("rect", xmin = xt, xmax = Inf, ymin = yt, ymax = Inf,
             fill = "#e8694c", alpha = 0.07) +
    geom_vline(xintercept = xt, linetype = "dashed", colour = "grey40") +
    geom_hline(yintercept = yt, linetype = "dashed", colour = "grey40") +
    geom_point(aes(colour = .data$ARM), size = 2.4, alpha = 0.85) +
    geom_point(data = flagged, shape = 21, size = 4.2, stroke = 1,
               colour = "#c0392b", fill = NA) +
    annotate("text", x = xt, y = Inf, label = "  Hy's Law zone", colour = "#c0392b",
             hjust = 0, vjust = 1.4, size = 3.4, fontface = "bold") +
    scale_x_log10() +
    scale_y_log10() +
    scale_colour_manual(values = arm_palette(cfg)) +
    labs(
      title = "Hy's Law / eDISH screening plot",
      subtitle = sprintf("Max post-baseline ALT vs Bilirubin (\u00d7 ULN); Hy's Law zone: ALT \u2265 %gx and Bilirubin \u2265 %gx", xt, yt),
      x = "Max post-baseline ALT (\u00d7 ULN, log scale)",
      y = "Max post-baseline Bilirubin (\u00d7 ULN, log scale)",
      colour = "Arm",
      caption = "FDA DILI screen using maximum post-baseline values; circled = potential Hy's Law"
    ) +
    theme_clinical() +
    theme(panel.grid.major.x = element_line(colour = clinical_grid, linewidth = 0.5))
}
