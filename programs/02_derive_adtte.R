# Derive a CDISC BDS time-to-event dataset (ADTTE) for the dermatologic-event endpoint.
# Endpoint TTDE: time to first treatment-emergent dermatologic / application-site AE.
# Reads data/adam/ADSL.rds + ADAE.rds, writes data/adam/ADTTE.rds.
# Run from project root: Rscript programs/02_derive_adtte.R

suppressPackageStartupMessages({
  library(dplyr)
})

adsl <- readRDS(file.path("data", "adam", "ADSL.rds"))
adae <- readRDS(file.path("data", "adam", "ADAE.rds"))

# Safety population only.
sl <- adsl %>%
  filter(.data$SAFFL == "Y") %>%
  mutate(
    cens_days = dplyr::coalesce(
      as.numeric(.data$TRTDURD),
      as.numeric(.data$TRTEDT - .data$TRTSDT) + 1
    )
  )

# Dermatologic event = treatment-emergent AND (application-site PT OR skin SOC).
derm_events <- adae %>%
  filter(
    .data$TRTEMFL == "Y",
    .data$USUBJID %in% sl$USUBJID,
    grepl("^APPLICATION SITE", .data$AEDECOD) |
      .data$AEBODSYS == "SKIN AND SUBCUTANEOUS TISSUE DISORDERS"
  ) %>%
  group_by(.data$USUBJID) %>%
  summarise(first_day = max(min(.data$ASTDY, na.rm = TRUE), 1), .groups = "drop")

adtte <- sl %>%
  left_join(derm_events, by = "USUBJID") %>%
  mutate(
    STUDYID  = .data$STUDYID,
    PARAMCD  = "TTDE",
    PARAM    = "Time to First Dermatologic Event (days)",
    CNSR     = ifelse(is.na(.data$first_day), 1L, 0L),
    AVAL     = ifelse(is.na(.data$first_day), .data$cens_days, .data$first_day),
    STARTDT  = .data$TRTSDT,
    EVNTDESC = ifelse(.data$CNSR == 0L,
                      "First dermatologic adverse event", "Censored"),
    CNSDTDSC = ifelse(.data$CNSR == 1L,
                      "End of treatment (no dermatologic event)", NA_character_)
  ) %>%
  filter(!is.na(.data$AVAL), .data$AVAL > 0) %>%
  select("STUDYID", "USUBJID", "ARM", "SAFFL", "PARAMCD", "PARAM",
         "AVAL", "CNSR", "STARTDT", "EVNTDESC", "CNSDTDSC")

dir.create(file.path("data", "adam"), recursive = TRUE, showWarnings = FALSE)
saveRDS(adtte, file.path("data", "adam", "ADTTE.rds"))

cat("Saved data/adam/ADTTE.rds\n")
cat(" Subjects:", nrow(adtte), "\n")
cat(" Events (CNSR=0):", sum(adtte$CNSR == 0), " Censored (CNSR=1):", sum(adtte$CNSR == 1), "\n")
cat("\nEvents by arm:\n")
print(as.data.frame(
  adtte %>% group_by(.data$ARM) %>%
    summarise(N = dplyr::n(), Events = sum(.data$CNSR == 0),
              `Median AVAL` = round(stats::median(.data$AVAL), 1), .groups = "drop")
))
