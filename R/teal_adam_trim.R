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
    "BASE", "CHG", "PCHG", "ANRIND", "BNRIND", "ABLFL", "ONTRTFL", "AVISIT", "AVISITN", "ADY",
    "ANRLO", "ANRHI"
  ),
  ADVS = c(
    "STUDYID", "USUBJID", "ARM", "SAFFL", "PARAM", "PARAMCD", "AVAL", "AVALU", "BASE", "CHG",
    "ABLFL", "AVISIT", "AVISITN"
  ),
  ADCM = c(
    "STUDYID", "USUBJID", "ARM", "CMTRT", "CMDECOD", "CMCLAS", "CMSEQ", "ASTDY", "AENDY",
    "ONTRTFL", "CMASTDTM", "CMAENDTM"
  ),
  ADEX = c(
    "STUDYID", "USUBJID", "ARM", "RACE", "SEX", "REGION1", "PARAMCD", "PARAM",
    "PARCAT1", "EXTRT", "EXDOSE", "EXDURD", "EXSTDY", "EXENDY", "AVAL", "AVALU",
    "AVISITN", "ASTDTM", "EXSEQ", "VISIT", "VISITNUM"
  ),
  ADMH = c("STUDYID", "USUBJID", "ARM", "MHTERM", "MHBODSYS", "MHSTDY", "MHOCCUR"),
  ADTTE = c(
    "STUDYID", "USUBJID", "ARM", "ARMCD", "SAFFL", "PARAMCD", "PARAM", "AVAL", "AVALU", "CNSR",
    "STARTDT", "EVNTDESC", "CNSDTDSC", "AGE", "RACE", "SEX", "AGEGR1"
  ),
  ADQS = c(
    "STUDYID", "USUBJID", "ARM", "ARMCD", "PARAM", "PARAMCD", "AVISIT", "AVAL", "BASE",
    "CHG", "STRATA1"
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

prep_adex_for_teal <- function(adex) {
  if (is.null(adex)) return(NULL)
  if (!"AVISITN" %in% names(adex)) {
    if ("VISITNUM" %in% names(adex)) {
      adex$AVISITN <- adex$VISITNUM
    } else if ("VISIT" %in% names(adex)) {
      adex$AVISITN <- as.numeric(factor(adex$VISIT))
    } else {
      adex$AVISITN <- 1L
    }
  }
  add_bds_avalu(adex)
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

prep_teal_arm_factor <- function(df, cfg) {
  if (is.null(df) || !"ARM" %in% names(df)) return(df)
  arms <- unlist(cfg$display$arm_levels, use.names = FALSE)
  df$ARM <- factor(df$ARM, levels = arms)
  df
}

normalize_teal_arm_levels <- function(df, cfg) {
  if (is.null(df)) return(df)
  arms <- unlist(cfg$display$arm_levels, use.names = FALSE)
  if ("ARM" %in% names(df)) df$ARM <- factor(as.character(df$ARM), levels = arms)
  if ("ACTARM" %in% names(df)) df$ACTARM <- factor(as.character(df$ACTARM), levels = arms)
  df
}

abnormality_na_level <- function() {
  lvl <- if (requireNamespace("tern", quietly = TRUE)) tern::default_na_str() else "<Missing>"
  if (length(lvl) == 0L || is.na(lvl) || !nzchar(lvl)) "<Missing>" else lvl
}

filter_abnormality_records <- function(df) {
  if (is.null(df) || nrow(df) == 0L) return(df)
  na_lvl <- abnormality_na_level()
  keep <- rep(TRUE, nrow(df))
  if ("ONTRTFL" %in% names(df)) {
    ontrt <- as.character(df$ONTRTFL)
    cond <- !is.na(ontrt) & ontrt == "Y"
    cond[is.na(cond)] <- FALSE
    keep <- keep & cond
  }
  for (v in c("ANRIND", "PARAM", "LBCAT")) {
    if (!v %in% names(df)) next
    col <- as.character(df[[v]])
    cond <- !is.na(col) & col != na_lvl
    cond[is.na(cond)] <- FALSE
    keep <- keep & cond
  }
  keep[is.na(keep)] <- FALSE
  df[keep, , drop = FALSE]
}

abnormality_transformators <- function(dataname = "ADLB") {
  list(
    teal::teal_transform_module(
      label = "On-treatment records with abnormality grade",
      datanames = dataname,
      server = function(id, data) {
        shiny::moduleServer(id, function(input, output, session) {
          shiny::reactive({
            ds <- data()
            df <- ds[[dataname]]
            if (is.null(df)) return(ds)
            ds[[dataname]] <- filter_abnormality_records(df)
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

adlb_tern_chars <- function(adlb) {
  if (is.null(adlb) || !requireNamespace("tern", quietly = TRUE)) return(adlb)
  cols <- intersect(
    c("ANRIND", "BNRIND", "AVISIT", "PARAM", "LBCAT", "ONTRTFL", "ABLFL", "PARAMCD", "ARM"),
    names(adlb)
  )
  if (length(cols) == 0L) return(adlb)
  for (col in cols) adlb[[col]] <- as.character(adlb[[col]])
  tern::df_explicit_na(adlb, omit_columns = setdiff(names(adlb), cols))
}

adsl_tern_chars <- function(adsl) {
  if (is.null(adsl) || !requireNamespace("tern", quietly = TRUE)) return(adsl)
  cols <- intersect(
    c("ARM", "ARMCD", "ACTARM", "SEX", "RACE", "ETHNIC", "EOSSTT", "DTHFL", "SAFFL"),
    names(adsl)
  )
  if (length(cols) == 0L) return(adsl)
  for (col in cols) adsl[[col]] <- as.character(adsl[[col]])
  tern::df_explicit_na(adsl, omit_columns = setdiff(names(adsl), cols))
}

trim_adsl_for_teal <- function(adsl, cfg) {
  if (is.null(adsl)) return(NULL)
  adsl <- prep_teal_arm_factor(adsl, cfg)
  adsl <- trim_teal_columns(adsl, "ADSL")
  adsl_tern_chars(adsl)
  normalize_teal_arm_levels(adsl, cfg)
}

trim_adlb_for_teal <- function(adlb, cfg) {
  if (is.null(adlb)) return(NULL)
  excl <- cfg$patient_profile$exclude_lbcat
  if (!is.null(excl) && "LBCAT" %in% names(adlb)) {
    adlb <- adlb[!(adlb$LBCAT %in% excl), , drop = FALSE]
  }
  adlb <- add_bds_avalu(adlb)
  adlb <- prep_teal_arm_factor(adlb, cfg)
  adlb <- trim_teal_columns(adlb, "ADLB")
  adlb <- adlb_tern_chars(adlb)
  adlb <- normalize_teal_arm_levels(adlb, cfg)
  order_avisit_factor(adlb)
}

trim_advs_for_teal <- function(advs, cfg) {
  if (is.null(advs)) return(NULL)
  params <- teal_advs_params(cfg)
  if (length(params) > 0L && "PARAM" %in% names(advs)) {
    advs <- advs[advs$PARAM %in% params, , drop = FALSE]
  }
  advs <- filter_scheduled_visits(advs, cfg)
  advs <- normalize_teal_arm_levels(advs, cfg)
  trim_teal_columns(order_avisit_factor(add_bds_avalu(advs)), "ADVS")
}

merge_adtte_demographics <- function(adtte, adsl) {
  if (is.null(adtte) || nrow(adtte) == 0L || is.null(adsl) || nrow(adsl) == 0L) {
    return(adtte)
  }
  demo_cols <- intersect(c("ARMCD", "AGE", "RACE", "SEX", "AGEGR1"), names(adsl))
  if (length(demo_cols) == 0L) return(adtte)

  sl <- adsl[, c("USUBJID", demo_cols), drop = FALSE]
  sl$USUBJID <- as.character(sl$USUBJID)
  adtte$USUBJID <- as.character(adtte$USUBJID)
  drop_demo <- intersect(demo_cols, names(adtte))
  if (length(drop_demo) > 0L) {
    adtte <- adtte[, setdiff(names(adtte), drop_demo), drop = FALSE]
  }
  out <- merge(adtte, sl, by = "USUBJID", all.x = TRUE)
  row.names(out) <- NULL
  out
}

prep_adcm_for_teal <- function(adcm) {
  if (is.null(adcm)) return(NULL)
  if ("ASTDTM" %in% names(adcm)) adcm$CMASTDTM <- adcm$ASTDTM
  if ("AENDTM" %in% names(adcm)) adcm$CMAENDTM <- adcm$AENDTM
  adcm
}

trim_adcm_for_teal <- function(adcm, cfg) {
  if (is.null(adcm)) return(NULL)
  adcm <- prep_teal_arm_factor(adcm, cfg)
  adcm <- prep_adcm_for_teal(adcm)
  adcm <- normalize_teal_arm_levels(adcm, cfg)
  trim_teal_columns(adcm, "ADCM")
}

trim_adex_for_teal <- function(adex, cfg) {
  if (is.null(adex)) return(NULL)
  trim_teal_columns(prep_adex_for_teal(adex), "ADEX")
}

adqs_tern_chars <- function(adqs) {
  if (is.null(adqs) || !requireNamespace("tern", quietly = TRUE)) return(adqs)
  # Keep STRATA1 as a plain covariate for summarize_ancova().
  cols <- intersect(c("ARM", "ARMCD", "PARAMCD", "AVISIT"), names(adqs))
  if (length(cols) == 0L) return(adqs)
  for (col in cols) adqs[[col]] <- as.character(adqs[[col]])
  tern::df_explicit_na(adqs, omit_columns = setdiff(names(adqs), cols))
}

trim_adqs_for_teal <- function(adqs, cfg) {
  if (is.null(adqs)) return(NULL)
  adqs <- prep_teal_arm_factor(adqs, cfg)
  adqs <- trim_teal_columns(adqs, "ADQS")
  adqs <- adqs_tern_chars(adqs)
  normalize_teal_arm_levels(adqs, cfg)
}

trim_teal_dataset <- function(df, dataname, cfg) {
  if (is.null(df) || !teal_optimize_enabled(cfg)) return(df)
  switch(dataname,
    ADSL = trim_adsl_for_teal(df, cfg),
    ADLB = trim_adlb_for_teal(df, cfg),
    ADVS = trim_advs_for_teal(df, cfg),
    ADCM = trim_adcm_for_teal(df, cfg),
    ADEX = trim_adex_for_teal(df, cfg),
    ADQS = trim_adqs_for_teal(df, cfg),
    trim_teal_columns(df, dataname)
  )
}

teal_dataset_summary <- function(ds_list) {
  vapply(names(ds_list), function(nm) {
    df <- ds_list[[nm]]
    sprintf("%s (%s rows x %s cols)", nm, format(nrow(df), big.mark = ","), ncol(df))
  }, character(1))
}
