# TLG Catalog -> teal.modules.clinical module factory.

arm_sel <- function() teal.transform::choices_selected(c("ARM", "ARMCD"), "ARM")

tlg_listing_module <- function(entry, dataname, cols, filter_fun = NULL) {
  label <- tlg_module_label(entry)
  teal::module(
    label = label,
    server = function(id, data, ...) {
      shiny::moduleServer(id, function(input, output, session) {
        output$lst <- shiny::renderUI({
          df <- data()[[dataname]]
          if (!is.null(filter_fun)) df <- filter_fun(df)
          if (nrow(df) == 0L) return(shiny::tags$p("No records match the listing criteria."))
          keep <- intersect(cols, names(df))
          lst <- rlistings::as_listing(df[, keep, drop = FALSE], key_cols = keep[1])
          teal.transform::table_inset(lst)
        })
      })
    },
    ui = function(id, ...) {
      ns <- shiny::NS(id)
      shiny::tagList(shiny::h4(label), shiny::uiOutput(ns("lst")))
    },
    datanames = dataname
  )
}

tlg_teal_module <- function(entry, cfg) {
  label <- tlg_module_label(entry)
  arm <- arm_sel()

  switch(entry$code,
    DMT01 = teal.modules.clinical::tm_t_summary(
      label = label,
      dataname = "ADSL",
      arm_var = arm,
      summarize_vars = teal.transform::choices_selected(c("AGE", "SEX", "RACE", "ETHNIC"), c("AGE", "SEX", "RACE")),
      useNA = "ifany"
    ),
    EXT01 = teal.modules.clinical::tm_t_exposure(
      label = label,
      dataname = "ADEX",
      col_by_var = arm,
      paramcd = teal.transform::choices_selected(
        choices = teal.transform::value_choices("ADEX", "PARAMCD", "PARAM"),
        selected = "DURD"
      )
    ),
    AET01 = teal.modules.clinical::tm_t_events_summary(
      label = label,
      dataname = "ADAE",
      arm_var = arm,
      flag_var_anl = teal.transform::choices_selected(c("SER", "SEV", "REL"), "SER"),
      add_total = TRUE
    ),
    AET02 = teal.modules.clinical::tm_t_events(
      label = label,
      dataname = "ADAE",
      arm_var = arm,
      llt = teal.transform::choices_selected("AEDECOD", "AEDECOD"),
      hlt = teal.transform::choices_selected("AEBODSYS", "AEBODSYS"),
      add_total = TRUE
    ),
    AET03 = teal.modules.clinical::tm_t_events_by_grade(
      label = label,
      dataname = "ADAE",
      arm_var = arm,
      llt = teal.transform::choices_selected("AEDECOD", "AEDECOD"),
      hlt = teal.transform::choices_selected("AEBODSYS", "AEBODSYS"),
      grade = teal.transform::choices_selected("AESEV", "AESEV"),
      add_total = TRUE
    ),
    AET10 = teal.modules.clinical::tm_t_events(
      label = label,
      dataname = "ADAE",
      arm_var = arm,
      llt = teal.transform::choices_selected("AEDECOD", "AEDECOD"),
      hlt = teal.transform::choices_selected("AEBODSYS", "AEBODSYS"),
      add_total = TRUE
    ),
    LBT01 = teal.modules.clinical::tm_g_lineplot(
      label = label,
      dataname = "ADLB",
      group_var = arm,
      x = teal.transform::choices_selected(teal.transform::variable_choices("ADLB", "AVISIT"), "AVISIT"),
      y = teal.transform::choices_selected(teal.transform::variable_choices("ADLB", c("AVAL", "CHG")), "AVAL"),
      paramcd = teal.transform::choices_selected(teal.transform::variable_choices("ADLB", "PARAMCD"), "PARAMCD"),
      param = teal.transform::choices_selected(teal.transform::value_choices("ADLB", "PARAMCD", "PARAM"), "Alanine Aminotransferase (U/L)")
    ),
    LTG01 = teal.modules.clinical::tm_g_lineplot(
      label = label,
      dataname = "ADLB",
      group_var = arm,
      x = teal.transform::choices_selected(teal.transform::variable_choices("ADLB", "AVISIT"), "AVISIT"),
      y = teal.transform::choices_selected(teal.transform::variable_choices("ADLB", c("AVAL", "CHG")), "AVAL"),
      paramcd = teal.transform::choices_selected(teal.transform::variable_choices("ADLB", "PARAMCD"), "PARAMCD"),
      param = teal.transform::choices_selected(teal.transform::value_choices("ADLB", "PARAMCD", "PARAM"), "Alanine Aminotransferase (U/L)")
    ),
    LBT04 = teal.modules.clinical::tm_t_shift_by_arm(
      label = label,
      dataname = "ADLB",
      arm_var = arm,
      paramcd = teal.transform::choices_selected(teal.transform::value_choices("ADLB", "PARAMCD", "PARAM"), "Alanine Aminotransferase (U/L)"),
      visit_var = teal.transform::choices_selected(teal.transform::variable_choices("ADLB", "AVISIT"), "AVISIT"),
      aval_var = teal.transform::choices_selected(teal.transform::variable_choices("ADLB", "ANRIND"), "ANRIND"),
      baseline_var = teal.transform::choices_selected(teal.transform::variable_choices("ADLB", "BNRIND"), "BNRIND")
    ),
    VST01 = teal.modules.clinical::tm_g_lineplot(
      label = label,
      dataname = "ADVS",
      group_var = arm,
      x = teal.transform::choices_selected(teal.transform::variable_choices("ADVS", "AVISIT"), "AVISIT"),
      y = teal.transform::choices_selected(teal.transform::variable_choices("ADVS", c("AVAL", "CHG")), "AVAL"),
      paramcd = teal.transform::choices_selected(teal.transform::variable_choices("ADVS", "PARAMCD"), "PARAMCD"),
      param = teal.transform::choices_selected(teal.transform::value_choices("ADVS", "PARAMCD", "PARAM"), "Systolic Blood Pressure (mmHg)")
    ),
    CMT01A = teal.modules.clinical::tm_t_summary(
      label = label,
      dataname = "ADCM",
      arm_var = arm,
      summarize_vars = teal.transform::choices_selected(c("CMDECOD", "CMCLAS", "CMTRT"), "CMDECOD"),
      useNA = "ifany"
    ),
    AEL03 = tlg_listing_module(
      entry, "ADAE",
      c("USUBJID", "ARM", "AEBODSYS", "AEDECOD", "AESEV", "AESER", "AEREL", "ASTDY"),
      filter_fun = function(df) dplyr::filter(df, .data$AESER == "Y")
    ),
    CML01 = tlg_listing_module(
      entry, "ADCM",
      c("USUBJID", "ARM", "CMTRT", "CMDECOD", "CMCLAS", "ASTDY", "AENDY", "ONTRTFL")
    ),
    EXL01 = tlg_listing_module(
      entry, "ADEX",
      c("USUBJID", "ARM", "EXTRT", "PARAM", "EXDOSE", "EXDURD", "EXSTDY", "EXENDY")
    ),
    LBL01 = tlg_listing_module(
      entry, "ADLB",
      c("USUBJID", "ARM", "PARAM", "AVISIT", "AVAL", "CHG", "ANRIND")
    ),
    MHL01 = tlg_listing_module(
      entry, "ADMH",
      c("USUBJID", "ARM", "MHTERM", "MHBODSYS", "MHSTDY", "MHOCCUR")
    ),
    KMG01 = teal.modules.clinical::tm_g_km(
      label = label,
      dataname = "ADTTE",
      arm_var = arm,
      paramcd = teal.transform::choices_selected(teal.transform::value_choices("ADTTE", "PARAMCD", "PARAM"), "TTDE"),
      aval_var = teal.transform::choices_selected(teal.transform::variable_choices("ADTTE", "AVAL"), "AVAL"),
      cnsr_var = teal.transform::choices_selected(teal.transform::variable_choices("ADTTE", "CNSR"), "CNSR")
    ),
    TTET01 = teal.modules.clinical::tm_t_tte(
      label = label,
      dataname = "ADTTE",
      arm_var = arm,
      paramcd = teal.transform::choices_selected(teal.transform::value_choices("ADTTE", "PARAMCD", "PARAM"), "TTDE"),
      aval_var = teal.transform::choices_selected(teal.transform::variable_choices("ADTTE", "AVAL"), "AVAL"),
      cnsr_var = teal.transform::choices_selected(teal.transform::variable_choices("ADTTE", "CNSR"), "CNSR")
    ),
    IPPG01 = teal.modules.clinical::tm_g_pp_patient_timeline(
      label = label,
      dataname_adae = "ADAE",
      dataname_adcm = "ADCM",
      patient_col = "USUBJID"
    ),
    NULL
  )
}

tlg_module_for_entry <- function(entry, cfg, inventory = NULL, registry = NULL) {
  if (!entry_has_data(entry, inventory)) {
    return(tlg_unavailable_module(entry, inventory))
  }
  if (identical(entry$implementation, "tern_layout")) {
    return(tlg_tern_module(entry))
  }
  if (identical(entry$implementation, "teal_module") && is_phase1_entry(entry, registry)) {
    mod <- tlg_teal_module(entry, cfg)
    if (!is.null(mod)) return(mod)
  }
  if (identical(entry$status, "ready") && identical(entry$implementation, "teal_module")) {
    mod <- tlg_teal_module(entry, cfg)
    if (!is.null(mod)) return(mod)
  }
  tlg_unavailable_module(entry, inventory)
}

build_tlg_modules <- function(registry, cfg, inventory = NULL) {
  by_cat <- tlg_entries_by_category(registry)
  cat_order <- c("tables", "listings", "graphs")
  cat_labels <- c(tables = "Tables", listings = "Listings", graphs = "Graphs")

  category_modules <- lapply(cat_order, function(cat) {
    entries <- by_cat[[cat]]
    if (is.null(entries) || length(entries) == 0L) return(NULL)
    domains <- tlg_domain_groups(entries)
    domain_mods <- lapply(names(domains), function(dom) {
      dom_entries <- domains[[dom]]
      mods <- lapply(dom_entries, function(e) {
        tlg_module_for_entry(e, cfg, inventory, registry)
      })
      do.call(teal::modules, c(mods, list(label = domain_display_name(dom))))
    })
    names(domain_mods) <- NULL
    do.call(teal::modules, c(domain_mods, list(label = cat_labels[[cat]])))
  })
  names(category_modules) <- NULL
  category_modules <- Filter(Negate(is.null), category_modules)

  ippg <- Filter(function(e) identical(e$code, "IPPG01"), registry$entries)[[1]]
  profile_mod <- if (!is.null(ippg)) {
    tlg_module_for_entry(ippg, cfg, inventory, registry)
  } else {
    NULL
  }

  all_mods <- category_modules
  if (!is.null(profile_mod)) all_mods <- c(all_mods, list(profile_mod))
  do.call(teal::modules, all_mods)
}
