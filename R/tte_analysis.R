# S10 Time-to-event analysis (TLG KMG01 plot + TTET01 summary).
# Kaplan-Meier of time to first dermatologic event by arm, using base survival.

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
  library(survival)
})

# ADTTE restricted to the TTDE parameter with ARM as an ordered factor.
.tte_ttde <- function(adtte, cfg) {
  adtte %>%
    filter(.data$PARAMCD == cfg$time_to_event$paramcd) %>%
    mutate(ARM = factor(.data$ARM, levels = arm_levels(cfg)),
           event = 1L - .data$CNSR) %>%
    filter(!is.na(.data$ARM))
}

# survfit object: event-free survival by arm (event = 1 - CNSR).
# Note: Surv() is evaluated in the data frame, so use bare column names (not .data$).
km_fit <- function(adtte, cfg) {
  d <- .tte_ttde(adtte, cfg)
  survival::survfit(survival::Surv(AVAL, event) ~ ARM, data = d)
}

# Log-rank p-value across arms.
km_logrank_p <- function(adtte, cfg) {
  d <- .tte_ttde(adtte, cfg)
  sd <- survival::survdiff(survival::Surv(AVAL, event) ~ ARM, data = d)
  stats::pchisq(sd$chisq, df = length(sd$n) - 1, lower.tail = FALSE)
}

# Tidy step coordinates from a survfit, with one row per arm stratum.
.km_steps <- function(fit, cfg) {
  strata <- rep(names(fit$strata), fit$strata)
  arm <- sub("^ARM=", "", strata)
  df <- data.frame(time = fit$time, surv = fit$surv, n.censor = fit$n.censor,
                   ARM = arm, stringsAsFactors = FALSE)
  # Prepend t=0, S=1 for each arm so curves start at the origin.
  starts <- data.frame(time = 0, surv = 1, n.censor = 0,
                       ARM = unique(arm), stringsAsFactors = FALSE)
  out <- bind_rows(starts, df)
  out$ARM <- factor(out$ARM, levels = arm_levels(cfg))
  out %>% arrange(.data$ARM, .data$time)
}

km_plot <- function(adtte, cfg) {
  fit <- km_fit(adtte, cfg)
  steps <- .km_steps(fit, cfg)
  cens <- steps %>% filter(.data$n.censor > 0)
  p_val <- km_logrank_p(adtte, cfg)
  p_lab <- ifelse(p_val < 0.001, "Log-rank p < 0.001",
                  sprintf("Log-rank p = %.3f", p_val))

  ggplot(steps, aes(x = .data$time, y = .data$surv, colour = .data$ARM)) +
    geom_step(linewidth = 0.9) +
    geom_point(data = cens, shape = 3, size = 2.2, show.legend = FALSE) +
    scale_colour_manual(values = arm_palette(cfg)) +
    scale_y_continuous(limits = c(0, 1), labels = scales::percent) +
    labs(
      title = "Time to first dermatologic adverse event by arm",
      subtitle = paste0("Kaplan-Meier (event-free survival) - pharmaverse TLG KMG01 | ", p_lab),
      x = "Days since first dose",
      y = "Probability free of dermatologic event",
      colour = "Arm",
      caption = "Event = first treatment-emergent application-site / skin AE; + = censored"
    ) +
    theme_clinical()
}

# TTET01-style summary: N, events, median time-to-event with 95% CI per arm.
km_median_table <- function(adtte, cfg) {
  fit <- km_fit(adtte, cfg)
  s <- summary(fit)$table
  if (is.null(dim(s))) s <- t(as.matrix(s))
  arms <- sub("^ARM=", "", rownames(s))
  fmt <- function(x) ifelse(is.na(x) | !is.finite(x), "NE", as.character(round(x, 0)))
  data.frame(
    Arm = factor(arms, levels = arm_levels(cfg)),
    N = as.integer(s[, "records"]),
    Events = as.integer(s[, "events"]),
    `Median (days)` = fmt(s[, "median"]),
    `95% CI lower` = fmt(s[, "0.95LCL"]),
    `95% CI upper` = fmt(s[, "0.95UCL"]),
    check.names = FALSE,
    stringsAsFactors = FALSE
  ) %>% arrange(.data$Arm)
}
