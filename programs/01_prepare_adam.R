# Load CDISC ADaM data from pharmaverseadam and save to data/simulated/
# Run from project root: Rscript R/pharmaverseadam.R

library(pharmaverseadam)

data(adsl)
data(adae)
data(adlb)

dir.create(file.path("data", "simulated"), recursive = TRUE, showWarnings = FALSE)

saveRDS(adsl, file.path("data", "simulated", "ADSL.rds"))
saveRDS(adae, file.path("data", "simulated", "ADAE.rds"))
saveRDS(adlb, file.path("data", "simulated", "ADLB.rds"))

cat("Saved:\n")
cat(" ADSL:", nrow(adsl), "rows\n")
cat(" ADAE:", nrow(adae), "rows\n")
cat(" ADLB:", nrow(adlb), "rows\n")
cat("Location: data/simulated/\n")
