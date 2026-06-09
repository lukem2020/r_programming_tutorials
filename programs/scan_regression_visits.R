# Scan visit coverage through lab regression pipeline (population + patient).
suppressPackageStartupMessages(library(dplyr))

for (f in c("load_data.R", "theme_clinical.R", "visit_aggregation.R", "trend_regression.R",
            "lab_analysis.R", "patient_profile.R")) {
  source(file.path("R", f))
}

st <- load_study_data(".")
cfg <- st$config
adlb <- st$ADLB

cat("=== All AVISIT values in ADLB (safety pop, numeric AVAL) ===\n")
visits <- adlb %>%
  filter(.data$SAFFL == "Y", !is.na(.data$AVAL)) %>%
  distinct(.data$AVISIT, .data$AVISITN) %>%
  arrange(.data$AVISITN)
print(visits)

cat("\n=== Visits matching Baseline|Week filter ===\n")
visit_ok <- grepl("^Baseline$|^Week", adlb$AVISIT)
print(visits %>% filter(grepl("^Baseline$|^Week", .data$AVISIT)))

cat("\n=== Visits NOT matching Baseline|Week filter ===\n")
print(visits %>% filter(!grepl("^Baseline$|^Week", .data$AVISIT)))

param <- default_lab_param(cfg, lab_param_catalog(adlb))
cat("\n=== Population pipeline for:", param, "===\n")

raw <- adlb %>%
  with_arm_factor(cfg) %>%
  filter(!is.na(.data$ARM), .data$PARAM == param,
         grepl("^Baseline$|^Week", .data$AVISIT), !is.na(.data$AVAL))
cat("Raw rows:", nrow(raw), "\n")
cat("Raw visits:\n")
print(raw %>% count(.data$AVISIT, .data$AVISITN) %>% arrange(.data$AVISITN))

after_mean <- raw %>%
  mean_by_visit(., c("USUBJID", "ARM", "AVISIT", "AVISITN"), "AVAL")
cat("\nAfter mean_by_visit (per subject-visit):\n")
print(after_mean %>% count(.data$AVISIT, .data$AVISITN) %>% arrange(.data$AVISITN))

ct <- lab_central_tendency(adlb, cfg, param)
cat("\nAfter lab_central_tendency (arm means):\n")
print(ct %>% select(.data$ARM, .data$AVISIT, .data$AVISITN, .data$mean, .data$n) %>%
        arrange(.data$ARM, .data$AVISITN))

ct_plot <- lab_central_tendency(adlb, cfg, param) %>%
  remove_lm_outliers(y_var = "mean", group_vars = "ARM")
cat("\nAfter remove_lm_outliers (what regression uses):\n")
for (arm in cfg$display$arm_levels) {
  sub <- ct_plot %>% filter(.data$ARM == arm) %>% arrange(.data$AVISITN)
  all_v <- ct %>% filter(.data$ARM == arm) %>% arrange(.data$AVISITN) %>% pull(.data$AVISIT)
  plot_v <- sub %>% pull(.data$AVISIT)
  missing <- setdiff(all_v, plot_v)
  cat("\n", arm, ":\n")
  cat("  Visits before outlier removal:", paste(all_v, collapse = ", "), "\n")
  cat("  Visits after outlier removal: ", paste(plot_v, collapse = ", "), "\n")
  if (length(missing) > 0) cat("  DROPPED:", paste(missing, collapse = ", "), "\n")
}

sid <- st$ADSL %>% filter(.data$SAFFL == "Y") %>% pull(.data$USUBJID) %>% .[1]
cat("\n=== Patient profile hepatic panel for", sid, "===\n")
spec <- patient_lab_panel_specs(cfg)[[1]]
rows <- .patient_lab_panel_rows(adlb, cfg, sid, spec)
cat("Visits per PARAM (after panel filter + mean_by_visit, before outlier removal):\n")
# peek inside - outlier removal is inside _rows now? Let me check

# _patient_lab_panel_rows applies mean_by_visit and outlier removal is in trend plot
before_out <- adlb %>%
  filter(.data$USUBJID == sid, grepl("^Baseline$|^Week", .data$AVISIT), !is.na(.data$AVAL),
         .data$PARAM %in% unname(liver_params(cfg))) %>%
  mean_by_visit(., c("USUBJID", "PARAM", "AVISIT", "AVISITN"), c("AVAL", "ANRHI"))

after_out <- before_out %>% remove_lm_outliers(y_var = "AVAL", group_vars = "PARAM")

for (p in unique(before_out$PARAM)) {
  b <- before_out %>% filter(.data$PARAM == p) %>% arrange(.data$AVISITN) %>% pull(.data$AVISIT)
  a <- after_out %>% filter(.data$PARAM == p) %>% arrange(.data$AVISITN) %>% pull(.data$AVISIT)
  miss <- setdiff(b, a)
  if (length(miss) > 0) {
    cat(" ", p, " DROPPED:", paste(miss, collapse = ", "), "\n")
  }
}

cat("\n=== Outlier removal on flat trends (no real outliers) - placebo ALT ===\n")
test <- ct %>% filter(.data$ARM == "Placebo")
cat("n visits:", nrow(test), "-> after outliers:", nrow(remove_lm_outliers(test, y_var="mean", group_vars="ARM")), "\n")
