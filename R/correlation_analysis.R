# S14 Spearman correlation of safety parameters by treatment arm.

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(ggplot2)
})

arm_slug <- function(arm) {
  gsub("_+", "_", gsub("[^A-Za-z0-9]+", "_", arm))
}

correlation_parameters <- function(cfg, adlb, advs = NULL) {
  want <- unlist(cfg$correlation_review$parameters, use.names = FALSE)
  have <- unique(adlb$PARAM)
  if (!is.null(advs)) have <- union(have, unique(advs$PARAM))
  out <- intersect(want, have)
  if (length(out) < 2L) {
    fallback <- c(
      unname(liver_params(cfg)),
      unlist(cfg$display$vs_params, use.names = FALSE)
    )
    out <- intersect(fallback, have)
  }
  out
}

.param_codes <- function(adlb, advs, params) {
  lb <- adlb %>%
    filter(.data$PARAM %in% params) %>%
    distinct(.data$PARAM, .data$PARAMCD)
  if (!is.null(advs)) {
    vs <- advs %>%
      filter(.data$PARAM %in% params) %>%
      distinct(.data$PARAM, .data$PARAMCD)
    lb <- bind_rows(lb, vs) %>% distinct(.data$PARAM, .data$PARAMCD)
  }
  lb
}

.subject_max_post_baseline <- function(df, params, cfg, ids) {
  if (is.null(df) || nrow(df) == 0L) {
    return(data.frame(
      USUBJID = character(), ARM = factor(levels = arm_levels(cfg)),
      PARAMCD = character(), value = double(), stringsAsFactors = FALSE
    ))
  }
  df %>%
    filter(.data$USUBJID %in% ids, .data$PARAM %in% params,
           grepl("^Week", .data$AVISIT), !is.na(.data$AVAL)) %>%
    with_arm_factor(cfg) %>%
    mean_by_visit(., c("USUBJID", "ARM", "PARAM", "PARAMCD", "AVISIT", "AVISITN"), "AVAL") %>%
    group_by(.data$USUBJID, .data$ARM, .data$PARAM, .data$PARAMCD) %>%
    summarise(value = max(.data$AVAL, na.rm = TRUE), .groups = "drop")
}

# One row per subject with max post-baseline values (wide PARAMCD columns).
subject_correlation_wide <- function(adlb, advs, adsl, cfg, params = NULL, arms = NULL) {
  if (is.null(params)) params <- correlation_parameters(cfg, adlb, advs)
  ids <- safety_subject_ids(adsl, cfg, arms)

  long <- bind_rows(
    .subject_max_post_baseline(adlb, params, cfg, ids),
    .subject_max_post_baseline(advs, params, cfg, ids)
  )

  if (nrow(long) == 0L) {
    return(data.frame(USUBJID = character(), ARM = factor(levels = arm_levels(cfg))))
  }

  long %>%
    distinct(.data$USUBJID, .data$ARM, .data$PARAMCD, .keep_all = TRUE) %>%
    select(.data$USUBJID, .data$ARM, .data$PARAMCD, .data$value) %>%
    pivot_wider(names_from = "PARAMCD", values_from = "value") %>%
    filter_by_arms(., cfg, arms)
}

spearman_correlation_matrix <- function(wide_df, arm, param_codes = NULL) {
  arm_df <- wide_df %>% filter(.data$ARM == arm)
  if (nrow(arm_df) < 3L) return(NULL)

  num_cols <- if (is.null(param_codes)) {
    names(arm_df)[vapply(arm_df, is.numeric, logical(1))]
  } else {
    intersect(param_codes, names(arm_df))
  }
  if (length(num_cols) < 2L) return(NULL)

  nums <- arm_df[, num_cols, drop = FALSE]
  stats::cor(nums, method = "spearman", use = "pairwise.complete.obs")
}

correlation_plot_height <- function(n_params) {
  max(320L, 80L + n_params * 30L)
}

spearman_correlation_heatmap <- function(cor_mat, arm, cfg) {
  if (is.null(cor_mat) || nrow(cor_mat) < 2L) {
    return(
      ggplot() +
        annotate("text", x = 1, y = 1,
                 label = paste0("Insufficient paired data for ", arm)) +
        theme_void()
    )
  }

  long <- as.data.frame(cor_mat)
  long$var_x <- rownames(cor_mat)
  long <- long %>%
    pivot_longer(-"var_x", names_to = "var_y", values_to = "rho") %>%
    mutate(
      var_x = factor(.data$var_x, levels = rownames(cor_mat)),
      var_y = factor(.data$var_y, levels = colnames(cor_mat))
    )

  ggplot(long, aes(x = .data$var_y, y = .data$var_x, fill = .data$rho)) +
    geom_tile(colour = "white", linewidth = 0.4) +
    geom_text(aes(label = sprintf("%.2f", .data$rho)), size = 2.8, colour = clinical_ink) +
    scale_fill_gradient2(
      low = "#4c9be8", mid = "#f4f6f8", high = "#e8694c",
      midpoint = 0, limits = c(-1, 1), name = "Spearman\nrho"
    ) +
    labs(
      title = paste0("Spearman correlation — ", arm),
      subtitle = "Max post-baseline safety parameters (pairwise complete observations)",
      x = NULL, y = NULL
    ) +
    theme_clinical() +
    theme(
      axis.text.x = element_text(angle = 45, hjust = 1, size = 9),
      axis.text.y = element_text(size = 9),
      panel.grid = element_blank()
    )
}

spearman_correlation_table <- function(wide_df, arm, param_codes = NULL) {
  mat <- spearman_correlation_matrix(wide_df, arm, param_codes)
  if (is.null(mat)) {
    return(data.frame(Note = sprintf("Insufficient data for %s", arm)))
  }
  out <- as.data.frame(mat, stringsAsFactors = FALSE)
  out <- cbind(Parameter = rownames(mat), out)
  rownames(out) <- NULL
  out
}
