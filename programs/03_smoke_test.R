# Smoke-test analysis helpers. Run: Rscript programs/03_smoke_test.R

for (f in c("load_data.R", "theme_clinical.R", "visit_aggregation.R", "trend_regression.R",
            "demographics.R", "exposure_analysis.R", "ae_analysis.R", "lab_analysis.R",
            "vs_analysis.R", "cm_analysis.R", "patient_profile.R", "tte_analysis.R",
            "correlation_analysis.R")) {
  source(file.path("R", f))
}
st <- load_study_data(".")
cfg <- st$config
stopifnot(!is.null(st$ADCM), !is.null(st$ADVS), !is.null(st$ADEX), !is.null(st$ADMH))

exposure_summary_table(st$ADSL, cfg)
exposure_detail_table(st$ADEX, st$ADSL, cfg)
teae_severity_table(st$ADAE, st$ADSL, cfg)
cm_summary_table(st$ADCM, st$ADSL, cfg)
cm_listing(st$ADCM, st$ADSL, cfg)
vs_central_tendency_plot(st$ADVS, cfg, st$config$display$vs_params[[1]])
stopifnot(length(vs_trend_params(st$ADVS)) == 8L)
outlier_df <- data.frame(
  AVISITN = 1:6, AVISIT = paste0("Week ", 1:6),
  mean = c(10, 11, 10, 12, 11, 50), ARM = "Placebo"
)
stopifnot(nrow(remove_lm_outliers(outlier_df, y_var = "mean", group_vars = "ARM")) < 6L)
stopifnot(!any(remove_lm_outliers(outlier_df, y_var = "mean", group_vars = "ARM")$mean == 50))
sid <- st$ADSL$USUBJID[1]
patient_vitals_panel_plot(st$ADVS, sid)
vs_raw <- st$ADVS %>%
  dplyr::filter(USUBJID == sid, PARAM == "Body Mass Index(kg/m^2)", AVISIT == "Week 4")
stopifnot(nrow(vs_raw) > 1L)
vs_agg <- mean_by_visit(
  vs_raw, c("USUBJID", "PARAM", "AVISIT", "AVISITN"), "AVAL"
)
stopifnot(nrow(vs_agg) == 1L)
lab_cat <- lab_param_catalog(st$ADLB)
cat("Lab params:", length(unique(unlist(lab_cat$by_category))), "\n")
lab_change_from_baseline_plot(st$ADLB, cfg, default_lab_param(cfg, lab_cat))
stopifnot(length(profile_subject_choices(st$ADSL, cfg, completed_only = TRUE)) > 0)
sid <- st$ADSL$USUBJID[1]
patient_lab_table(st$ADLB, cfg, sid)
stopifnot(!any(patient_lab_table(st$ADLB, cfg, sid)$Category == "OTHER", na.rm = TRUE))
panels <- patient_lab_panels_for_subject(st$ADLB, cfg, sid)
stopifnot(length(panels) >= 3L)
for (panel in panels) {
  patient_lab_panel_trend_plot(st$ADLB, cfg, sid, panel)
}
cat("Lab panels for subject:", paste(vapply(panels, `[[`, "", "id"), collapse = ", "), "\n")
patient_mh_table(st$ADMH, st$ADSL$USUBJID[1])

cparams <- correlation_parameters(cfg, st$ADLB, st$ADVS)
wide <- subject_correlation_wide(st$ADLB, st$ADVS, st$ADSL, cfg, cparams)
mat <- spearman_correlation_matrix(wide, cfg$display$arm_levels[[1]], pull(.param_codes(st$ADLB, st$ADVS, cparams), PARAMCD))
stopifnot(!is.null(mat), nrow(mat) >= 2L)
spearman_correlation_heatmap(mat, cfg$display$arm_levels[[1]], cfg)

top_teae <- teae_top_terms(st$ADAE, st$ADSL, cfg)
stopifnot(length(top_teae) == cfg$display$top_n_ae)
all_tte <- tte_all_endpoint_choices(cfg, st$ADAE, st$ADSL)
stopifnot(length(all_tte) == length(tte_endpoint_choices(cfg)) + length(top_teae))

if (!is.null(st$ADTTE)) {
  for (pc in tte_endpoint_choices(cfg)) {
    km_plot(st$ADTTE, cfg, pc, st$ADSL, st$ADAE)
    km_median_table(st$ADTTE, cfg, pc, st$ADSL, st$ADAE)
  }
}
km_plot(st$ADTTE, cfg, pt_endpoint_id(top_teae[[1]]), st$ADSL, st$ADAE)
km_median_table(st$ADTTE, cfg, pt_endpoint_id(top_teae[[1]]), st$ADSL, st$ADAE)

cat("Smoke test passed.\n")
