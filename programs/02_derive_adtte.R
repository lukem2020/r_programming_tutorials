# Derive CDISC BDS ADTTE for configured time-to-event endpoints.
# Run from project root: Rscript programs/02_derive_adtte.R

suppressPackageStartupMessages({
  library(dplyr)
  library(yaml)
})

cfg <- read_yaml(file.path("config", "study_config.yml"))
adsl <- readRDS(file.path("data", "adam", "ADSL.rds"))
adae <- readRDS(file.path("data", "adam", "ADAE.rds"))

sl <- adsl %>%
  filter(.data$SAFFL == "Y") %>%
  mutate(
    cens_days = dplyr::coalesce(
      as.numeric(.data$TRTDURD),
      as.numeric(.data$TRTEDT - .data$TRTSDT) + 1
    )
  )

derive_tte_endpoint <- function(sl, adae, endpoint) {
  soc <- endpoint$event_soc
  prefix <- endpoint$event_decod_prefix

  flagged <- adae %>%
    filter(.data$TRTEMFL == "Y", .data$USUBJID %in% sl$USUBJID)

  if (!is.null(prefix) && nzchar(prefix)) {
    flagged <- flagged %>%
      filter(
        grepl(paste0("^", prefix), .data$AEDECOD) |
          .data$AEBODSYS == soc
      )
  } else {
    flagged <- flagged %>% filter(.data$AEBODSYS == soc)
  }

  first_events <- flagged %>%
    group_by(.data$USUBJID) %>%
    summarise(first_day = max(min(.data$ASTDY, na.rm = TRUE), 1), .groups = "drop")

  sl %>%
    left_join(first_events, by = "USUBJID") %>%
    mutate(
      STUDYID  = .data$STUDYID,
      PARAMCD  = endpoint$paramcd,
      PARAM    = endpoint$param,
      CNSR     = ifelse(is.na(.data$first_day), 1L, 0L),
      AVAL     = ifelse(is.na(.data$first_day), .data$cens_days, .data$first_day),
      STARTDT  = .data$TRTSDT,
      EVNTDESC = ifelse(.data$CNSR == 0L, endpoint$event_label, "Censored"),
      CNSDTDSC = ifelse(.data$CNSR == 1L, endpoint$censor_label, NA_character_)
    ) %>%
    filter(!is.na(.data$AVAL), .data$AVAL > 0) %>%
    select("STUDYID", "USUBJID", "ARM", "SAFFL", "PARAMCD", "PARAM",
           "AVAL", "CNSR", "STARTDT", "EVNTDESC", "CNSDTDSC")
}

adtte <- bind_rows(lapply(cfg$time_to_event_endpoints, derive_tte_endpoint, sl = sl, adae = adae))

dir.create(file.path("data", "adam"), recursive = TRUE, showWarnings = FALSE)
saveRDS(adtte, file.path("data", "adam", "ADTTE.rds"))

cat("Saved data/adam/ADTTE.rds\n")
cat(" Subjects x endpoints:", nrow(adtte), "rows\n")
for (ep in cfg$time_to_event_endpoints) {
  sub <- adtte %>% filter(.data$PARAMCD == ep$paramcd)
  cat("\n", ep$paramcd, "—", ep$label, "\n")
  cat("  Subjects:", nrow(sub),
      "| Events:", sum(sub$CNSR == 0),
      "| Censored:", sum(sub$CNSR == 1), "\n")
  print(as.data.frame(
    sub %>%
      group_by(.data$ARM) %>%
      summarise(N = dplyr::n(), Events = sum(.data$CNSR == 0),
                `Median AVAL` = round(stats::median(.data$AVAL), 1), .groups = "drop")
  ))
}
