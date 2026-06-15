# Slim ADaM domains for the teal app (smaller memory + faster module compute).

TEAL_DATASET_COLUMNS <- list(
  ADSL = c(
    "STUDYID", "USUBJID", "ARM", "ARMCD", "ACTARM", "SAFFL", "SEX", "RACE", "AGEGR1",
    "AGE", "ETHNIC", "EOSSTT", "DTHFL", "REGION1", "TRTSDT", "TRTEDT", "TRTDURD"
  ),
  ADAE = c(
    "STUDYID", "USUBJID", "ARM", "TRTEMFL", "AEDECOD", "AEBODSYS", "AESEV", "AESER",
    "AEREL", "AETERM", "ASTDT", "ASTDTM", "AENDTM", "ASTDY", "AENDY", "AESEQ",
    "SER", "SEV", "REL", "AESDTH", "AEACN"
  ),
  ADLB = c(
    "STUDYID", "USUBJID", "ARM", "SAFFL", "PARAM", "PARAMCD", "LBCAT", "AVAL", "AVALU",
    "BASE", "CHG", "ANRIND", "BNRIND", "ABLFL", "AVISIT", "AVISITN", "ADY", "ANRLO", "ANRHI"
  ),
  ADVS = c(
    "STUDYID", "USUBJID", "ARM", "SAFFL", "PARAM", "PARAMCD", "AVAL", "AVALU", "BASE", "CHG",
    "ABLFL", "AVISIT", "AVISITN"
  ),
  ADCM = c(
    "STUDYID", "USUBJID", "ARM", "CMTRT", "CMDECOD", "CMCLAS", "ASTDY", "AENDY",
    "ONTRTFL", "ASTDTM", "AENDTM"
  ),
  ADEX = c(
    "STUDYID", "USUBJID", "ARM", "RACE", "SEX", "REGION1", "PARAMCD", "PARAM",
    "PARCAT1", "EXTRT", "EXDOSE", "EXDURD", "EXSTDY", "EXENDY"
  ),
  ADMH = c("STUDYID", "USUBJID", "ARM", "MHTERM", "MHBODSYS", "MHSTDY", "MHOCCUR"),
  ADTTE = c(
    "STUDYID", "USUBJID", "ARM", "SAFFL", "PARAMCD", "PARAM", "AVAL", "AVALU", "CNSR",
    "STARTDT", "EVNTDESC", "CNSDTDSC"
  )
)

teal_optimize_enabled <- function(cfg) {
  block <- cfg$teal_app
  is.null(block) || !identical(block$optimize_datasets, FALSE)
}

teal_advs_params <- function(cfg) {
  block <- cfg$teal_app
  if (!is.null(block$advs_params)) return(unlist(block$advs_params, use.names = FALSE))
  unlist(cfg$display$vs_params, use.names = FALSE)
}

# tm_g_lineplot expects AVALU; CDISCPILOT01 ADLB/ADVS omit it — parse units from PARAM labels.
derive_avalu_from_param <- function(param) {
  out <- sub("^.*\\(([^)]+)\\)$", "\\1", param)
  ifelse(out == param, "UNIT", out)
}

add_bds_avalu <- function(df) {
  if (is.null(df) || "AVALU" %in% names(df) || !"PARAM" %in% names(df)) return(df)
  df$AVALU <- derive_avalu_from_param(df$PARAM)
  df
}

scheduled_visit_pattern <- function(cfg = NULL) {
  block <- if (!is.null(cfg)) cfg$teal_app else NULL
  pat <- block$scheduled_visit_pattern
  if (!is.null(pat)) return(pat)
  "^Baseline$|^Week"
}

is_scheduled_bds_visit <- function(avisit, cfg = NULL) {
  grepl(scheduled_visit_pattern(cfg), avisit)
}

filter_scheduled_visits <- function(df, cfg = NULL) {
  if (is.null(df) || !"AVISIT" %in% names(df)) return(df)
  df[is_scheduled_bds_visit(df$AVISIT, cfg), , drop = FALSE]
}

order_avisit_factor <- function(df) {
  if (is.null(df) || !all(c("AVISIT", "AVISITN") %in% names(df))) return(df)
  visit_tbl <- unique(df[, c("AVISIT", "AVISITN")])
  visit_tbl <- visit_tbl[order(visit_tbl$AVISITN, visit_tbl$AVISIT), , drop = FALSE]
  levels <- visit_tbl$AVISIT[!duplicated(visit_tbl$AVISIT)]
  df$AVISIT <- factor(df$AVISIT, levels = levels)
  df
}

scheduled_bds_transformators <- function(dataname, cfg = NULL) {
  list(
    teal::teal_transform_module(
      label = "Scheduled visits only",
      datanames = dataname,
      server = function(id, data) {
        shiny::moduleServer(id, function(input, output, session) {
          shiny::reactive({
            ds <- data()
            df <- ds[[dataname]]
            if (is.null(df)) return(ds)
            df <- filter_scheduled_visits(df, cfg)
            df <- order_avisit_factor(df)
            ds[[dataname]] <- df
            ds
          })
        })
      }
    )
  )
}

trim_teal_columns <- function(df, dataname) {
  if (is.null(df) || !dataname %in% names(TEAL_DATASET_COLUMNS)) return(df)
  keep <- intersect(TEAL_DATASET_COLUMNS[[dataname]], names(df))
  if (length(keep) == 0L) return(df)
  df[, keep, drop = FALSE]
}

trim_adlb_for_teal <- function(adlb, cfg) {
  if (is.null(adlb)) return(NULL)
  excl <- cfg$patient_profile$exclude_lbcat
  if (!is.null(excl) && "LBCAT" %in% names(adlb)) {
    adlb <- adlb[!(adlb$LBCAT %in% excl), , drop = FALSE]
  }
  trim_teal_columns(order_avisit_factor(add_bds_avalu(adlb)), "ADLB")
}

trim_advs_for_teal <- function(advs, cfg) {
  if (is.null(advs)) return(NULL)
  params <- teal_advs_params(cfg)
  if (length(params) > 0L && "PARAM" %in% names(advs)) {
    advs <- advs[advs$PARAM %in% params, , drop = FALSE]
  }
  advs <- filter_scheduled_visits(advs, cfg)
  trim_teal_columns(order_avisit_factor(add_bds_avalu(advs)), "ADVS")
}

trim_teal_dataset <- function(df, dataname, cfg) {
  if (is.null(df) || !teal_optimize_enabled(cfg)) return(df)
  switch(dataname,
    ADLB = trim_adlb_for_teal(df, cfg),
    ADVS = trim_advs_for_teal(df, cfg),
    trim_teal_columns(df, dataname)
  )
}

teal_dataset_summary <- function(ds_list) {
  vapply(names(ds_list), function(nm) {
    df <- ds_list[[nm]]
    sprintf("%s (%s rows x %s cols)", nm, format(nrow(df), big.mark = ","), ncol(df))
  }, character(1))
}
