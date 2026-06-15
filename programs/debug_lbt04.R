# LBT04 abnormality table diagnostic (writes lbt04_debug.txt).
# Run: Rscript programs/debug_lbt04.R

if (file.exists("renv/activate.R")) source("renv/activate.R")
Sys.setenv(RENV_CONFIG_SANDBOX_ENABLED = "FALSE")

suppressPackageStartupMessages({
  library(dplyr)
  library(rtables)
  library(tern)
})

for (f in c("load_data.R", "teal_adam_trim.R", "teal_study_data.R")) {
  source(file.path("R", f))
}

out <- file("lbt04_debug.txt", open = "wt")
sink(out, split = TRUE)
on.exit({
  sink()
  close(out)
}, add = TRUE)

cfg <- load_config(".")
adsl <- load_teal_dataset(".", cfg, "ADSL")
adlb <- load_teal_dataset(".", cfg, "ADLB")
adlb_f <- filter_abnormality_records(adlb)

cat("ADSL rows:", nrow(adsl), " ARM class:", class(adsl$ARM), "\n")
cat("ADLB rows:", nrow(adlb), " -> filtered:", nrow(adlb_f), "\n")
for (v in c("ANRIND", "BNRIND", "PARAM", "ONTRTFL")) {
  cat(v, "class:", class(adlb_f[[v]]), "levels:", paste(levels(adlb_f[[v]]), collapse = ","), "\n")
}

na_lvl <- abnormality_na_level()
for (v in c("PARAM", "LBCAT", "ANRIND")) {
  if (v %in% names(adlb_f)) {
    cat(v, "missing/<Missing>:", sum(is.na(adlb_f[[v]]) | adlb_f[[v]] == na_lvl, na.rm = TRUE), "\n")
  }
}

lyt <- basic_table(show_colcounts = TRUE) %>%
  split_cols_by("ARM") %>%
  split_rows_by("PARAM", label_pos = "topleft") %>%
  count_abnormal(
    var = "ANRIND",
    abnormal = list(Low = "LOW", High = "HIGH"),
    variables = list(id = "USUBJID", baseline = "BNRIND"),
    exclude_base_abn = TRUE
  )

tbl <- build_table(lyt, adlb_f, alt_counts_df = adsl)
cat("Table built:", nrow(tbl), "x", ncol(tbl), "\n")
cat("OK\n")
