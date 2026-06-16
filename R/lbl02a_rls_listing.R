# LBL02A_RLS — Listing of Laboratory Abnormalities (Roche Safety Lab Standardization).
# Ported from TLG Catalog listings/lab-results/lbl02a_rls.qmd (CDISCPILOT01 mapping).

derive_listing_cpid <- function(usubjid) {
  vapply(usubjid, function(id) {
    parts <- strsplit(as.character(id), "-", fixed = TRUE)[[1]]
    if (length(parts) >= 3L) {
      paste(paste(parts[seq_len(length(parts) - 1L)], collapse = "-"), parts[length(parts)], sep = "/")
    } else {
      as.character(id)
    }
  }, character(1))
}

derive_lbtest_u <- function(param, avalu = NULL, lbtest = NULL) {
  param <- as.character(param)
  if (!is.null(lbtest) && any(!is.na(lbtest) & nzchar(lbtest))) {
    unit <- if (is.null(avalu)) rep("UNIT", length(param)) else as.character(avalu)
    unit[is.na(unit) | unit == ""] <- "UNIT"
    return(paste0(lbtest, " (", unit, ")"))
  }
  param
}

lbl02a_rls_patient_choices <- function(adlb) {
  if (is.null(adlb) || nrow(adlb) == 0L || !"USUBJID" %in% names(adlb)) {
    return(stats::setNames(character(), character()))
  }
  ids <- sort(unique(adlb$USUBJID))
  cpids <- derive_listing_cpid(ids)
  stats::setNames(ids, cpids)
}

build_lbl02a_rls_listing <- function(adlb, usubjid = NULL) {
  if (!requireNamespace("dplyr", quietly = TRUE)) {
    stop("Package 'dplyr' is required for LBL02A_RLS.", call. = FALSE)
  }
  if (!requireNamespace("rlistings", quietly = TRUE)) {
    stop("Package 'rlistings' is required for LBL02A_RLS.", call. = FALSE)
  }
  `%>%` <- dplyr::`%>%`

  empty_listing <- function(msg) {
    rlistings::as_listing(
      data.frame(Note = msg),
      key_cols = "Note",
      disp_cols = "Note",
      main_title = "Listing of Laboratory Abnormalities Defined by Roche Safety Lab Standardization"
    )
  }

  if (is.null(adlb) || nrow(adlb) == 0L) {
    return(empty_listing("No laboratory data available."))
  }

  if (!is.null(usubjid) && length(usubjid) == 1L && nzchar(usubjid)) {
    adlb <- adlb[adlb$USUBJID == usubjid, , drop = FALSE]
    if (nrow(adlb) == 0L) {
      return(empty_listing("No laboratory data for the selected patient."))
    }
  }

  need <- c("USUBJID", "ARM", "PARAM", "ADY", "AVAL", "ANRIND", "ANRLO", "ANRHI")
  miss <- setdiff(need, names(adlb))
  if (length(miss) > 0L) {
    return(empty_listing(paste("ADLB is missing required variables:", paste(miss, collapse = ", "))))
  }

  pchg <- if ("PCHG" %in% names(adlb)) {
    adlb$PCHG
  } else if (all(c("CHG", "BASE") %in% names(adlb))) {
    100 * adlb$CHG / adlb$BASE
  } else {
    rep(NA_real_, nrow(adlb))
  }

  avalu <- if ("AVALU" %in% names(adlb)) adlb$AVALU else NULL
  lbtest <- if ("LBTEST" %in% names(adlb)) adlb$LBTEST else NULL

  adlb_x <- adlb %>%
    dplyr::filter(!is.na(.data$PARAM), .data$PARAM != "") %>%
    dplyr::mutate(
      LBTEST_U = derive_lbtest_u(.data$PARAM, avalu, lbtest),
      TRT01A = as.character(.data$ARM),
      CPID = derive_listing_cpid(.data$USUBJID),
      CRC = "40% / 40%",
      PCHG = pchg
    )

  std_rng <- adlb_x %>%
    dplyr::group_by(.data$LBTEST_U) %>%
    dplyr::summarise(
      STD_RNG_LO = stats::quantile(.data$AVAL, probs = 0.1, na.rm = TRUE),
      STD_RNG_HI = stats::quantile(.data$AVAL, probs = 0.9, na.rm = TRUE),
      .groups = "drop"
    )

  out <- adlb_x %>%
    dplyr::left_join(std_rng, by = "LBTEST_U") %>%
    dplyr::mutate(
      ANRIND_FLAG = dplyr::case_when(
        .data$ANRIND == "LOW" & .data$AVAL > .data$STD_RNG_LO ~ "L",
        .data$ANRIND == "HIGH" & .data$AVAL < .data$STD_RNG_HI ~ "H",
        .data$ANRIND == "LOW" & .data$AVAL <= .data$STD_RNG_LO ~ "LL",
        .data$ANRIND == "HIGH" & .data$AVAL >= .data$STD_RNG_HI ~ "HH",
        TRUE ~ ""
      ),
      AVAL = format(round(.data$AVAL, 1), nsmall = 1),
      PCHG = format(round(.data$PCHG, 1), nsmall = 1),
      LBNRNG = paste(.data$ANRLO, .data$ANRHI, sep = " - "),
      STD_RNG_LO = format(round(.data$STD_RNG_LO, 1), nsmall = 1),
      STD_RNG_HI = format(round(.data$STD_RNG_HI, 1), nsmall = 1),
      STD_RNG = paste(.data$STD_RNG_LO, .data$STD_RNG_HI, sep = " - "),
      ANRIND = factor(.data$ANRIND_FLAG)
    ) %>%
    dplyr::select(
      LBTEST_U, TRT01A, CPID, ADY, AVAL, PCHG, STD_RNG, LBNRNG, CRC, ANRIND
    ) %>%
    dplyr::distinct() %>%
    dplyr::filter(.data$ANRIND %in% c("L", "H", "LL", "HH")) %>%
    dplyr::arrange(.data$CPID, .data$ADY) %>%
    dplyr::group_by(.data$LBTEST_U, .data$CPID) %>%
    dplyr::mutate(DLD = .data$ADY - dplyr::lag(.data$ADY)) %>%
    dplyr::ungroup() %>%
    dplyr::mutate(DLD = ifelse(is.na(.data$DLD), 0, .data$DLD)) %>%
    dplyr::select(
      LBTEST_U, TRT01A, CPID, ADY, DLD, AVAL, PCHG, STD_RNG, LBNRNG, CRC, ANRIND
    )

  if (nrow(out) == 0L) {
    return(empty_listing("No laboratory abnormalities under Roche Safety Lab Standardization rules."))
  }

  if (requireNamespace("formatters", quietly = TRUE)) {
    formatters::var_labels(out) <- names(out)
    out <- formatters::var_relabel(
      out,
      LBTEST_U = "Lab Test (Unit)",
      TRT01A = "Treatment",
      CPID = "Center/Patient ID",
      ADY = "Study\nDay",
      DLD = "Days Since\nLast Dose of\nStudy Drug",
      AVAL = "Result",
      PCHG = "% Change\nfrom\nBaseline",
      STD_RNG = "Standard\nReference\nRange",
      LBNRNG = "Marked\nReference\nRange",
      CRC = "Clinically\nRelevant\nChange\nDec./Inc.",
      ANRIND = "Abnormality\nFlag"
    )
  }

  rlistings::as_listing(
    out,
    key_cols = c("TRT01A", "LBTEST_U", "CPID"),
    disp_cols = names(out),
    main_title = "Listing of Laboratory Abnormalities Defined by Roche Safety Lab Standardization",
    main_footer = paste(
      "Standard reference range, marked reference range and clinically relevant change from baseline",
      "are from the Roche Safety Lab Standardization guideline. Abnormalities are flagged as",
      "high (H) or low (L) if outside the standard reference range; high high (HH) or low low",
      "(LL) if outside the marked reference range with a clinically relevant change from baseline."
    )
  )
}
