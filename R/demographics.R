# S1 Demographics (TLG DMT01) and S2 Disposition (TLG DST01).

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
})

# Wide demographics table: one row per characteristic, one column per arm.
demographics_table <- function(adsl, cfg) {
  d <- safety_adsl(adsl, cfg)
  denom <- d %>% count(.data$ARM, name = "den")

  n_row <- d %>%
    count(.data$ARM) %>%
    transmute(.data$ARM, Characteristic = "N", Value = as.character(.data$n))

  age_row <- d %>%
    group_by(.data$ARM) %>%
    summarise(m = mean(.data$AGE), s = sd(.data$AGE), .groups = "drop") %>%
    transmute(.data$ARM, Characteristic = "Age, mean (SD)",
              Value = sprintf("%.1f (%.1f)", .data$m, .data$s))

  sex_rows <- d %>%
    count(.data$ARM, .data$SEX) %>%
    left_join(denom, by = "ARM") %>%
    transmute(.data$ARM, Characteristic = paste0("Sex: ", .data$SEX),
              Value = sprintf("%d (%.1f%%)", .data$n, 100 * .data$n / .data$den))

  race_rows <- d %>%
    count(.data$ARM, .data$RACE) %>%
    left_join(denom, by = "ARM") %>%
    transmute(.data$ARM,
              Characteristic = paste0("Race: ", tools::toTitleCase(tolower(.data$RACE))),
              Value = sprintf("%d (%.1f%%)", .data$n, 100 * .data$n / .data$den))

  out <- bind_rows(n_row, age_row, sex_rows, race_rows)
  out$Characteristic <- factor(out$Characteristic, levels = unique(out$Characteristic))
  out %>%
    pivot_wider(names_from = "ARM", values_from = "Value", values_fill = "0") %>%
    arrange(.data$Characteristic) %>%
    rename(` ` = "Characteristic")
}

# S2 Disposition: end-of-study status counts by arm (EOSSTT).
disposition_table <- function(adsl, cfg) {
  d <- safety_adsl(adsl, cfg)
  denom <- d %>% count(.data$ARM, name = "den")
  d %>%
    filter(!is.na(.data$EOSSTT)) %>%
    count(.data$ARM, .data$EOSSTT) %>%
    left_join(denom, by = "ARM") %>%
    transmute(.data$ARM,
              Status = tools::toTitleCase(tolower(.data$EOSSTT)),
              Value = sprintf("%d (%.1f%%)", .data$n, 100 * .data$n / .data$den)) %>%
    pivot_wider(names_from = "ARM", values_from = "Value", values_fill = "0")
}
