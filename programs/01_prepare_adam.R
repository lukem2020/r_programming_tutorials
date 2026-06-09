# Load CDISC ADaM data from pharmaverseadam and save to data/adam/
# Run from project root: Rscript programs/01_prepare_adam.R

library(pharmaverseadam)

domains <- c("adsl", "adae", "adlb", "adex", "advs", "adcm", "admh")
dir.create(file.path("data", "adam"), recursive = TRUE, showWarnings = FALSE)

for (d in domains) {
  data(list = d, package = "pharmaverseadam")
  x <- get(d)
  out <- file.path("data", "adam", paste0(toupper(d), ".rds"))
  saveRDS(x, out)
  cat(" Saved", toupper(d), ":", nrow(x), "rows ->", out, "\n")
}

cat("\nNext: Rscript programs/02_derive_adtte.R\n")
