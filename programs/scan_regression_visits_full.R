# Full scan: visits dropped by outlier removal across params and arms.
suppressPackageStartupMessages(library(dplyr))

for (f in c("load_data.R", "theme_clinical.R", "visit_aggregation.R", "trend_regression.R",
            "lab_analysis.R", "patient_profile.R")) {
  source(file.path("R", f))
}

st <- load_study_data(".")
cfg <- st$config
adlb <- st$ADLB
catalog <- lab_param_catalog(adlb)
params <- unlist(catalog$by_category)

cat("=== SCHEDULED VISITS IN ADLB (no Week 1 exists) ===\n")
adlb %>%
  filter(.data$SAFFL == "Y", grepl("^Baseline$|^Week", .data$AVISIT)) %>%
  distinct(.data$AVISIT, .data$AVISITN) %>%
  arrange(.data$AVISITN) %>%
  print()

drops <- list()
for (param in params) {
  ct <- lab_central_tendency(adlb, cfg, param)
  after <- remove_lm_outliers(ct, y_var = "mean", group_vars = "ARM")
  for (arm in cfg$display$arm_levels) {
    before_v <- ct %>% filter(.data$ARM == arm) %>% arrange(.data$AVISITN) %>% pull(.data$AVISIT)
    after_v <- after %>% filter(.data$ARM == arm) %>% arrange(.data$AVISITN) %>% pull(.data$AVISIT)
    miss <- setdiff(before_v, after_v)
    if (length(miss) > 0) {
      drops[[length(drops) + 1]] <- data.frame(
        param = param, arm = arm, dropped = paste(miss, collapse = "; "),
        stringsAsFactors = FALSE
      )
    }
  }
}
cat("\n=== POPULATION LAB TRENDS: visits dropped by remove_lm_outliers ===\n")
if (length(drops) == 0) {
  cat("None\n")
} else {
  print(bind_rows(drops))
  cat("Total arm-param combinations with drops:", nrow(bind_rows(drops)), "\n")
}

cat("\n=== PATIENT PROFILE: sample of 20 subjects, hepatic panel ===\n")
sids <- st$ADSL %>% filter(.data$SAFFL == "Y") %>% pull(.data$USUBJID) %>% head(20)
spec <- patient_lab_panel_specs(cfg)[[1]]
pp_drops <- 0
for (sid in sids) {
  before <- .patient_lab_panel_rows(adlb, cfg, sid, spec)
  after <- before %>% remove_lm_outliers(y_var = "AVAL", group_vars = "PARAM")
  for (p in unique(before$PARAM)) {
    miss <- setdiff(
      before %>% filter(.data$PARAM == p) %>% pull(.data$AVISIT),
      after %>% filter(.data$PARAM == p) %>% pull(.data$AVISIT)
    )
    if (length(miss) > 0) pp_drops <- pp_drops + 1
  }
}
cat("Subject-param pairs with dropped visits (first 20 subjects, hepatic):", pp_drops, "\n")
