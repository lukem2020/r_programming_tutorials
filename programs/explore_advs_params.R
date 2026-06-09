# List all vital sign parameters in ADVS vs dashboard config.
suppressPackageStartupMessages(library(dplyr))

source("R/load_data.R")
source("R/vs_analysis.R")

st <- load_study_data(".")
advs <- st$ADVS
cfg <- st$config

cat("=== ADVS dimensions ===\n")
print(dim(advs))

cat("\n=== Unique PARAM:", length(unique(advs$PARAM)), "===\n")
print(sort(unique(advs$PARAM)))

cat("\n=== PARAM + PARAMCD ===\n")
print(advs %>% distinct(.data$PARAM, .data$PARAMCD) %>% arrange(.data$PARAM) %>% as.data.frame())

if ("VSCAT" %in% names(advs)) {
  cat("\n=== By VSCAT ===\n")
  print(table(advs$VSCAT, useNA = "ifany"))
  print(advs %>%
          distinct(.data$PARAM, .data$PARAMCD, .data$VSCAT) %>%
          arrange(.data$VSCAT, .data$PARAM) %>%
          as.data.frame())
}

want <- unlist(cfg$display$vs_params, use.names = FALSE)
have <- unique(advs$PARAM)

cat("\n=== Config vs_params (", length(want), ") ===\n")
print(want)

cat("\n=== vs_param_choices() output ===\n")
print(vs_param_choices(cfg, advs))

cat("\n=== In config but NOT in ADVS ===\n")
print(setdiff(want, have))

cat("\n=== In ADVS but NOT in config (candidates to add) ===\n")
print(setdiff(have, want))

cat("\n=== Scheduled visits with AVAL per PARAM ===\n")
visit_ok <- grepl("^Baseline$|^Week", advs$AVISIT)
print(advs %>%
        filter(visit_ok, !is.na(.data$AVAL)) %>%
        group_by(.data$PARAM) %>%
        summarise(n = n(), visits = n_distinct(.data$AVISIT), .groups = "drop") %>%
        arrange(.data$PARAM) %>%
        as.data.frame())

missing_trend <- setdiff(unique(advs$PARAM),
                         advs %>% filter(visit_ok, !is.na(.data$AVAL)) %>% pull(.data$PARAM) %>% unique())
cat("\n=== CHG available at Week visits ===\n")
print(advs %>%
        filter(grepl("^Week", .data$AVISIT), !is.na(.data$CHG)) %>%
        group_by(.data$PARAM) %>%
        summarise(n = n(), .groups = "drop") %>%
        arrange(.data$PARAM) %>%
        as.data.frame())

if (length(missing_trend) > 0) {
  cat("\n=== PARAM with no Baseline/Week AVAL (screening-only or derived) ===\n")
  print(missing_trend)
  print(advs %>%
          filter(.data$PARAM %in% missing_trend) %>%
          distinct(.data$PARAM, .data$AVISIT, .data$AVAL) %>%
          arrange(.data$PARAM, .data$AVISIT) %>%
          as.data.frame())
}
