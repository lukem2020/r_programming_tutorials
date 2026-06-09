# Linear regression trends over scheduled analysis visits (x = AVISITN).

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
})

visit_axis_scale <- function(df, visitn = "AVISITN", visit = "AVISIT") {
  labs_df <- df %>%
    distinct(.data[[visitn]], .data[[visit]]) %>%
    arrange(.data[[visitn]])
  scale_x_continuous(
    breaks = labs_df[[visitn]],
    labels = labs_df[[visit]]
  )
}

geom_lm_trend <- function(se = TRUE, linewidth = 0.9, alpha = 0.18, ...) {
  geom_smooth(
    method = "lm",
    formula = y ~ x,
    se = se,
    linewidth = linewidth,
    alpha = alpha,
    ...
  )
}

.trim_lm_group_outliers <- function(g, x_var, y_var, iqr_mult, resid_cutoff) {
  if (nrow(g) < 3L) return(g)
  y <- g[[y_var]]
  if (!all(is.finite(y))) return(g)

  # Pass 1: Tukey IQR fence on y (stable with few visits).
  q <- stats::quantile(y, c(0.25, 0.75), na.rm = TRUE)
  iqr <- unname(q[2] - q[1])
  if (is.finite(iqr) && iqr > 0) {
    fence <- iqr_mult * iqr
    keep <- y >= (q[1] - fence) & y <= (q[2] + fence)
    if (sum(keep) >= 2L) g <- g[keep, , drop = FALSE]
  }

  if (nrow(g) < 3L) return(g)
  x <- g[[x_var]]
  if (!all(is.finite(x))) return(g)

  # Pass 2: studentized residuals from a provisional linear model.
  fit <- tryCatch(
    stats::lm(stats::as.formula(paste(y_var, "~", x_var)), data = g),
    error = function(e) NULL
  )
  if (is.null(fit)) return(g)
  res <- abs(stats::rstandard(fit))
  keep <- is.finite(res) & res <= resid_cutoff
  if (sum(keep) < 2L) return(g)
  g[keep, , drop = FALSE]
}

# Subset used for linear-model fit only (scheduled visit points stay on the chart).
lm_fit_data <- function(df, y_var = "mean", group_vars = NULL, ...) {
  remove_lm_outliers(df, y_var = y_var, group_vars = group_vars, ...)
}

# Drop outliers within each regression group before fitting linear trends.
remove_lm_outliers <- function(df, x_var = "AVISITN", y_var = "mean",
                               group_vars = NULL, iqr_mult = 1.5,
                               resid_cutoff = 2.5) {
  if (nrow(df) == 0L) return(df)
  trim <- function(g) .trim_lm_group_outliers(g, x_var, y_var, iqr_mult, resid_cutoff)
  if (is.null(group_vars) || length(group_vars) == 0L) {
    trim(df)
  } else {
    df %>%
      group_by(across(all_of(group_vars))) %>%
      group_modify(~ trim(.x)) %>%
      ungroup()
  }
}
