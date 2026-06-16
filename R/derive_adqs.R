# Derive a questionnaire-style ADQS BDS for efficacy ANCOVA (AOVT01).
# CDISCPILOT01 has no native ADQS; we map scheduled vital-sign change scores
# at Week 12 to the catalog AOVT01 structure (PARAMCD, CHG, BASE, STRATA1).

derive_adqs_for_aovt <- function(
  advs,
  adsl,
  visits = c("Week 8", "Week 12", "End of Treatment"),
  paramcds = c("SYSBP", "DIABP", "PULSE", "WEIGHT", "TEMP", "MAP")
) {
  if (is.null(advs) || is.null(adsl) || nrow(advs) == 0L || nrow(adsl) == 0L) {
    return(advs[0, , drop = FALSE])
  }

  need_advs <- c("USUBJID", "PARAM", "PARAMCD", "AVISIT", "AVAL", "BASE", "CHG")
  miss <- setdiff(need_advs, names(advs))
  if (length(miss) > 0L) {
    stop("ADVS is missing variables required for ADQS derivation: ", paste(miss, collapse = ", "), call. = FALSE)
  }

  if ("SAFFL" %in% names(adsl)) {
    adsl <- adsl[adsl$SAFFL == "Y", , drop = FALSE]
  }

  strata1 <- if ("STRATA1" %in% names(adsl) && any(!is.na(adsl$STRATA1))) {
    as.character(adsl$STRATA1)
  } else if ("SEX" %in% names(adsl)) {
    as.character(adsl$SEX)
  } else if ("REGION1" %in% names(adsl) && any(!is.na(adsl$REGION1))) {
    as.character(adsl$REGION1)
  } else if ("AGEGR1" %in% names(adsl)) {
    as.character(adsl$AGEGR1)
  } else {
    rep("Overall", nrow(adsl))
  }

  sl_usubjid <- as.character(adsl$USUBJID)
  sl <- data.frame(
    USUBJID = sl_usubjid,
    ARM = adsl$ARM,
    ARMCD = as.character(adsl$ARMCD),
    STRATA1 = strata1,
    stringsAsFactors = FALSE
  )
  if ("STUDYID" %in% names(adsl)) sl$STUDYID <- adsl$STUDYID

  advs_usubjid <- as.character(advs$USUBJID)
  paramcd_chr <- as.character(advs$PARAMCD)
  visits <- as.character(visits)
  keep <- advs_usubjid %in% sl_usubjid &
    as.character(advs$AVISIT) %in% visits &
    paramcd_chr %in% paramcds &
    !is.na(advs$CHG)
  if ("ABLFL" %in% names(advs)) {
    keep <- keep & (is.na(advs$ABLFL) | advs$ABLFL != "Y")
  }

  out <- advs[keep, c("USUBJID", "PARAM", "PARAMCD", "AVISIT", "AVAL", "BASE", "CHG"), drop = FALSE]
  out <- unique(out)
  out$USUBJID <- as.character(out$USUBJID)
  idx <- match(out$USUBJID, sl$USUBJID)
  out$ARM <- sl$ARM[idx]
  out$ARMCD <- sl$ARMCD[idx]
  out$STRATA1 <- sl$STRATA1[idx]
  if ("STUDYID" %in% names(sl)) out$STUDYID <- sl$STUDYID[idx]
  out <- out[!is.na(out$ARMCD) & !is.na(out$STRATA1) & nzchar(out$STRATA1), , drop = FALSE]

  if (nrow(out) == 0L) return(out)

  out$PARAMCD <- factor(as.character(out$PARAMCD), levels = paramcds)
  out$AVISIT <- factor(as.character(out$AVISIT), levels = visits)
  out$STRATA1 <- factor(out$STRATA1)
  out$ARMCD <- factor(out$ARMCD)
  row.names(out) <- NULL
  out
}
