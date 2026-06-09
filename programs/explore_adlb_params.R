# Explore ADLB parameters. Run: Rscript programs/explore_adlb_params.R

suppressPackageStartupMessages(library(dplyr))

adlb <- readRDS(file.path("data", "adam", "ADLB.rds"))

cat("=== ADLB overview ===\n")
cat("Rows:", nrow(adlb), " Subjects:", n_distinct(adlb$USUBJID), "\n\n")

cat("=== LBCAT (lab categories) ===\n")
print(count(adlb, LBCAT, sort = TRUE), n = 50)

params <- adlb %>%
  distinct(PARAM, PARAMCD, LBCAT) %>%
  arrange(LBCAT, PARAM)

cat("\n=== All PARAM (", nrow(params), " unique) ===\n")
print(params, n = 200)

cat("\n=== Currently in dashboard (hepatic_safety / liver_params) ===\n")
cat("  - Alanine Aminotransferase (U/L)\n")
cat("  - Aspartate Aminotransferase (U/L)\n")
cat("  - Bilirubin (umol/L)\n")

current <- c(
  "Alanine Aminotransferase (U/L)",
  "Aspartate Aminotransferase (U/L)",
  "Bilirubin (umol/L)"
)

other <- params %>% filter(!PARAM %in% current)
cat("\n=== Other parameters (", nrow(other), ") by category ===\n")
for (cat_name in unique(other$LBCAT)) {
  sub <- other %>% filter(LBCAT == cat_name)
  cat("\n--", cat_name, "(", nrow(sub), " params ) --\n")
  print(sub %>% select(PARAM, PARAMCD), n = 50)
}

# Safety-relevant common adds for MDR
cat("\n=== Suggested MDR additions (renal, haematology, chemistry) ===\n")
suggest_pat <- "CREAT|UREA|BUN|GFR|EGFR|HGB|HEMOGLOBIN|PLAT|WBC|NEUT|LYMPH|ALT|AST|BILI|ALP|ALBUMIN|GLUC|CHOL|POTASS|SODIUM|CALCIUM"
suggested <- params %>%
  filter(grepl(suggest_pat, PARAM, ignore.case = TRUE) | grepl(suggest_pat, PARAMCD, ignore.case = TRUE)) %>%
  filter(!PARAM %in% current)
print(suggested, n = 50)
