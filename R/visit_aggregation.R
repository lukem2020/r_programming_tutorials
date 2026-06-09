# Collapse replicate measurements at the same analysis visit (mean).

suppressPackageStartupMessages({
  library(dplyr)
})

mean_by_visit <- function(df, group_cols, value_cols = NULL) {
  group_cols <- intersect(group_cols, names(df))
  if (length(group_cols) == 0L || nrow(df) == 0L) return(df)

  if (is.null(value_cols)) {
    value_cols <- setdiff(
      names(df)[vapply(df, is.numeric, logical(1))],
      group_cols
    )
  } else {
    value_cols <- intersect(value_cols, names(df))
  }
  if (length(value_cols) == 0L) return(df)

  df %>%
    group_by(across(all_of(group_cols))) %>%
    summarise(
      across(all_of(value_cols), ~ {
        x <- .x
        if (all(is.na(x))) NA_real_ else mean(x, na.rm = TRUE)
      }),
      .groups = "drop"
    )
}
