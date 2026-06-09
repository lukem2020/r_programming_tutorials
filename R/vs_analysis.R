# S12 Vital signs over time (teal vitals line plot / VST01).

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
})

vs_param_choices <- function(cfg, advs) {
  want <- unlist(cfg$display$vs_params, use.names = FALSE)
  have <- unique(advs$PARAM)
  out <- intersect(want, have)
  if (length(out) == 0) have
  else out
}

# All ADVS parameters with numeric values at Baseline/Week visits (trend-plottable).
vs_trend_params <- function(advs) {
  advs %>%
    filter(grepl("^Baseline$|^Week", .data$AVISIT), !is.na(.data$AVAL)) %>%
    distinct(.data$PARAM, .data$PARAMCD) %>%
    arrange(.data$PARAMCD) %>%
    pull(.data$PARAM)
}

vs_central_tendency <- function(advs, cfg, param, arms = NULL) {
  advs %>%
    with_arm_factor(cfg) %>%
    filter_by_arms(., cfg, arms) %>%
    filter(!is.na(.data$ARM), .data$PARAM == param,
           grepl("^Baseline$|^Week", .data$AVISIT), !is.na(.data$AVAL)) %>%
    mean_by_visit(., c("USUBJID", "ARM", "AVISIT", "AVISITN"), "AVAL") %>%
    group_by(.data$ARM, .data$AVISIT, .data$AVISITN) %>%
    summarise(mean = mean(.data$AVAL), sd = sd(.data$AVAL), n = dplyr::n(), .groups = "drop") %>%
    arrange(.data$AVISITN)
}

vs_central_tendency_plot <- function(advs, cfg, param, arms = NULL) {
  df_all <- vs_central_tendency(advs, cfg, param, arms)
  if (nrow(df_all) == 0) {
    return(ggplot() +
             annotate("text", x = 1, y = 1, label = "No vital sign data for this parameter") +
             theme_void())
  }
  df_fit <- lm_fit_data(df_all, y_var = "mean", group_vars = "ARM")
  dodge <- position_dodge(width = 0.35)
  ggplot(df_all, aes(x = .data$AVISITN, y = .data$mean, colour = .data$ARM, group = .data$ARM)) +
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
      caption = "Points = all scheduled visits; regression uses non-outlier visits only (IQR + studentized residuals)"
    ) +
    theme_clinical() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))
}
