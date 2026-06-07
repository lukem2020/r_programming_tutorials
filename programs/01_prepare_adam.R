# Load CDISC ADaM data from pharmaverseadam and save to data/adam/
# Run from project root: Rscript programs/01_prepare_adam.R

library(pharmaverseadam)

data(adsl)
data(adae)
data(adlb)

dir.create(file.path("data", "adam"), recursive = TRUE, showWarnings = FALSE)

saveRDS(adsl, file.path("data", "adam", "ADSL.rds"))
saveRDS(adae, file.path("data", "adam", "ADAE.rds"))
saveRDS(adlb, file.path("data", "adam", "ADLB.rds"))

cat("Saved:\n")
cat(" ADSL:", nrow(adsl), "rows\n")
cat(" ADAE:", nrow(adae), "rows\n")
cat(" ADLB:", nrow(adlb), "rows\n")
cat("Location: data/adam/\n")
