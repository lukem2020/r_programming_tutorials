# TLG Catalog -> teal.modules.clinical module factory.

arm_sel <- function() teal.transform::choices_selected(c("ARM", "ARMCD"), "ARM")

adsl_strata_sel <- function(selected = "SEX") {
  teal.transform::choices_selected(
    teal.transform::variable_choices("ADSL", c("SEX", "RACE", "AGEGR1")),
    selected
  )
}

adsl_facet_sel <- function() {
  teal.transform::choices_selected(
    teal.transform::variable_choices("ADSL", c("SEX", "RACE", "AGEGR1")),
    NULL
  )
}

bds_y_unit <- function(dataname) {
  teal.transform::choices_selected(
    teal.transform::variable_choices(dataname, subset = "AVALU"),
    "AVALU"
  )
}

tlg_listing_module <- function(entry, dataname, cols, filter_fun = NULL) {
  label <- tlg_module_label(entry)
  teal::module(
    label = label,
    server = function(id, data, ...) {
      shiny::moduleServer(id, function(input, output, session) {
        output$lst <- DT::renderDT({
          df <- data()[[dataname]]
          if (!is.null(filter_fun)) df <- filter_fun(df)
          if (nrow(df) == 0L) return(NULL)
          keep <- intersect(cols, names(df))
          DT::datatable(
            df[, keep, drop = FALSE],
            options = list(pageLength = 25, scrollX = TRUE, lengthMenu = c(25, 50, 100)),
            rownames = FALSE,
            filter = "top"
          )
        })
      })
    },
    ui = function(id, ...) {
      ns <- shiny::NS(id)
      shiny::tagList(shiny::h4(label), DT::DTOutput(ns("lst")))
    },
    datanames = dataname
  )
}

tlg_teal_module <- function(entry, cfg) {
  label <- tlg_module_label(entry)
  arm <- arm_sel()
  lineplot_scheduled <- function(dataname) scheduled_bds_transformators(dataname, cfg)

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
      row_by_var = teal.transform::choices_selected(
        teal.transform::variable_choices("ADEX", c("RACE", "SEX", "REGION1")),
        "RACE"
      ),
      paramcd = teal.transform::choices_selected(
        choices = teal.transform::value_choices("ADEX", "PARAMCD", "PARAM"),
        selected = "TDURD"
      ),
      parcat = teal.transform::choices_selected(
        teal.transform::value_choices("ADEX", "PARCAT1"),
        "OVERALL"
      ),
      add_total = FALSE
    ),
    AET01 = teal.modules.clinical::tm_t_events_summary(
      label = label,
      dataname = "ADAE",
      arm_var = arm,
      flag_var_anl = teal.transform::choices_selected(c("SER", "SEV", "REL"), "SER"),
      dthfl_var = teal.transform::choices_selected(
        teal.transform::variable_choices("ADSL", subset = "DTHFL"),
        "DTHFL"
      ),
      dcsreas_var = teal.transform::choices_selected(
        teal.transform::variable_choices("ADSL", subset = "EOSSTT"),
        "EOSSTT"
      ),
      count_wd = FALSE,
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
      x = teal.transform::choices_selected(teal.transform::variable_choices("ADLB", subset = "AVISIT"), "AVISIT"),
      y = teal.transform::choices_selected(teal.transform::variable_choices("ADLB", subset = c("AVAL", "CHG")), "AVAL"),
      y_unit = bds_y_unit("ADLB"),
      paramcd = teal.transform::choices_selected(teal.transform::variable_choices("ADLB", subset = "PARAMCD"), "PARAMCD"),
      param = teal.transform::choices_selected(teal.transform::value_choices("ADLB", "PARAMCD", "PARAM"), "ALT"),
      transformators = lineplot_scheduled("ADLB")
    ),
    LTG01 = teal.modules.clinical::tm_g_lineplot(
      label = label,
      dataname = "ADLB",
      group_var = arm,
      x = teal.transform::choices_selected(teal.transform::variable_choices("ADLB", subset = "AVISIT"), "AVISIT"),
      y = teal.transform::choices_selected(teal.transform::variable_choices("ADLB", subset = c("AVAL", "CHG")), "AVAL"),
      y_unit = bds_y_unit("ADLB"),
      paramcd = teal.transform::choices_selected(teal.transform::variable_choices("ADLB", subset = "PARAMCD"), "PARAMCD"),
      param = teal.transform::choices_selected(teal.transform::value_choices("ADLB", "PARAMCD", "PARAM"), "ALT"),
      transformators = lineplot_scheduled("ADLB")
    ),
    LBT04 = teal.modules.clinical::tm_t_shift_by_arm(
      label = label,
      dataname = "ADLB",
      arm_var = arm,
      paramcd = teal.transform::choices_selected(
        teal.transform::value_choices("ADLB", "PARAMCD", "PARAM"),
        "ALT"
      ),
      visit_var = teal.transform::choices_selected(
        teal.transform::value_choices("ADLB", "AVISIT"),
        "POST-BASELINE MINIMUM"
      ),
      aval_var = teal.transform::choices_selected(
        teal.transform::variable_choices("ADLB", subset = "ANRIND"),
        "ANRIND",
        fixed = TRUE
      ),
      baseline_var = teal.transform::choices_selected(
        teal.transform::variable_choices("ADLB", subset = "BNRIND"),
        "BNRIND",
        fixed = TRUE
      ),
      useNA = "ifany"
    ),
    VST01 = teal.modules.clinical::tm_g_lineplot(
      label = label,
      dataname = "ADVS",
      group_var = arm,
      x = teal.transform::choices_selected(teal.transform::variable_choices("ADVS", subset = "AVISIT"), "AVISIT"),
      y = teal.transform::choices_selected(teal.transform::variable_choices("ADVS", subset = c("AVAL", "CHG")), "AVAL"),
      y_unit = bds_y_unit("ADVS"),
      paramcd = teal.transform::choices_selected(teal.transform::variable_choices("ADVS", subset = "PARAMCD"), "PARAMCD"),
      param = teal.transform::choices_selected(teal.transform::value_choices("ADVS", "PARAMCD", "PARAM"), "SYSBP")
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
      paramcd = teal.transform::choices_selected(
        teal.transform::value_choices("ADTTE", "PARAMCD", "PARAM"),
        "TTDE"
      ),
      strata_var = adsl_strata_sel("SEX"),
      facet_var = adsl_facet_sel(),
      aval_var = teal.transform::choices_selected(
        teal.transform::variable_choices("ADTTE", subset = "AVAL"),
        "AVAL"
      ),
      cnsr_var = teal.transform::choices_selected(
        teal.transform::variable_choices("ADTTE", subset = "CNSR"),
        "CNSR"
      ),
      time_unit_var = teal.transform::choices_selected(
        teal.transform::variable_choices("ADTTE", subset = "AVALU"),
        "AVALU"
      )
    ),
    TTET01 = teal.modules.clinical::tm_t_tte(
      label = label,
      dataname = "ADTTE",
      arm_var = arm,
      paramcd = teal.transform::choices_selected(
        teal.transform::value_choices("ADTTE", "PARAMCD", "PARAM"),
        "TTDE"
      ),
      strata_var = adsl_strata_sel("SEX"),
      time_points = teal.transform::choices_selected(c(30, 60, 90, 180), 30),
      aval_var = teal.transform::choices_selected(
        teal.transform::variable_choices("ADTTE", subset = "AVAL"),
        "AVAL"
      ),
      cnsr_var = teal.transform::choices_selected(
        teal.transform::variable_choices("ADTTE", subset = "CNSR"),
        "CNSR"
      ),
      time_unit_var = teal.transform::choices_selected(
        teal.transform::variable_choices("ADTTE", subset = "AVALU"),
        "AVALU"
      )
    ),
    IPPG01 = teal.modules.clinical::tm_g_pp_patient_timeline(
      label = label,
      dataname_adae = "ADAE",
      dataname_adcm = "ADCM",
      patient_col = "USUBJID",
      aeterm = teal.transform::choices_selected(
        teal.transform::variable_choices("ADAE", "AETERM"),
        "AETERM"
      ),
      cmdecod = teal.transform::choices_selected(
        teal.transform::variable_choices("ADCM", subset = "CMDECOD"),
        "CMDECOD"
      ),
      aetime_start = teal.transform::choices_selected(
        teal.transform::variable_choices("ADAE", subset = "ASTDTM"),
        "ASTDTM"
      ),
      aetime_end = teal.transform::choices_selected(
        teal.transform::variable_choices("ADAE", subset = "AENDTM"),
        "AENDTM"
      ),
      dstime_start = teal.transform::choices_selected(
        teal.transform::variable_choices("ADCM", subset = "ASTDTM"),
        "ASTDTM"
      ),
      dstime_end = teal.transform::choices_selected(
        teal.transform::variable_choices("ADCM", subset = "AENDTM"),
        "AENDTM"
      ),
      aerelday_start = teal.transform::choices_selected(
        teal.transform::variable_choices("ADAE", subset = "ASTDY"),
        "ASTDY"
      ),
      aerelday_end = teal.transform::choices_selected(
        teal.transform::variable_choices("ADAE", subset = "AENDY"),
        "AENDY"
      ),
      dsrelday_start = teal.transform::choices_selected(
        teal.transform::variable_choices("ADCM", subset = "ASTDY"),
        "ASTDY"
      ),
      dsrelday_end = teal.transform::choices_selected(
        teal.transform::variable_choices("ADCM", subset = "AENDY"),
        "AENDY"
      )
    ),
    NULL
  )
}

tlg_module_for_entry <- function(entry, cfg, inventory = NULL, registry = NULL, root = NULL) {
  if (!entry_has_data(entry, inventory, root)) return(NULL)
  if (!entry_is_runnable(entry, registry)) return(NULL)
  if (identical(entry$implementation, "tern_layout")) {
    return(tlg_tern_module(entry))
  }
  if (identical(entry$implementation, "teal_module")) {
    mod <- tlg_teal_module(entry, cfg)
    if (!is.null(mod)) return(mod)
  }
  NULL
}

build_tlg_modules <- function(registry, cfg, inventory = NULL, root = NULL) {
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
        tlg_module_for_entry(e, cfg, inventory, registry, root)
      })
      mods <- Filter(Negate(is.null), mods)
      if (length(mods) == 0L) return(NULL)
      do.call(teal::modules, c(mods, list(label = domain_display_name(dom))))
    })
    names(domain_mods) <- NULL
    domain_mods <- Filter(Negate(is.null), domain_mods)
    if (length(domain_mods) == 0L) return(NULL)
    do.call(teal::modules, c(domain_mods, list(label = cat_labels[[cat]])))
  })
  names(category_modules) <- NULL
  category_modules <- Filter(Negate(is.null), category_modules)
  if (length(category_modules) == 0L) {
    stop("No runnable TLG modules after registry filter.", call. = FALSE)
  }
  do.call(teal::modules, category_modules)
}
