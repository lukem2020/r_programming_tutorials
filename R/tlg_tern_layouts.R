# tern/rtables layouts ported from TLG Catalog (CDISCPILOT01 variable mapping).

suppressPackageStartupMessages({
  library(tern)
  library(rtables)
  library(formatters)
  library(dplyr)
})

tern_table_as_ui <- function(tbl) {
  txt <- if (requireNamespace("rtables", quietly = TRUE) && inherits(tbl, "VTableTree")) {
    paste(rtables::toString(tbl), collapse = "\n")
  } else {
    paste(as.character(tbl), collapse = "\n")
  }
  shiny::tags$div(
    style = "overflow-x: auto;",
    shiny::tags$pre(
      style = "white-space: pre; font-size: 11px; font-family: monospace;",
      txt
    )
  )
}

tern_table_module <- function(entry, build_fun, datanames = "ADSL") {
  label <- tlg_module_label(entry)
  teal::module(
    label = label,
    server = function(id, data, ...) {
      shiny::moduleServer(id, function(input, output, session) {
        output$table <- shiny::renderUI({
          tryCatch({
            tern_table_as_ui(build_fun(data()))
          }, error = function(e) {
            shiny::tags$div(
              class = "alert alert-danger",
              style = "margin-top: 1rem;",
              shiny::tags$strong("Table failed to render: "),
              conditionMessage(e)
            )
          })
        })
      })
    },
    ui = function(id, ...) {
      ns <- shiny::NS(id)
      shiny::tagList(
        shiny::h4(label),
        shiny::uiOutput(ns("table"))
      )
    },
    datanames = datanames
  )
}

build_dmt01 <- function(data) {
  adsl <- data[["ADSL"]]
  vars <- intersect(c("AGE", "SEX", "RACE", "ETHNIC"), names(adsl))
  labels <- c(AGE = "Age (yr)", SEX = "Sex", RACE = "Race", ETHNIC = "Ethnicity")
  basic_table(show_colcounts = TRUE) %>%
    split_cols_by("ARM") %>%
    add_overall_col("All Patients") %>%
    analyze_vars(
      vars = vars,
      var_labels = labels[vars]
    ) %>%
    build_table(adsl)
}

build_dst01 <- function(data) {
  adsl <- data[["ADSL"]]
  if (!"EOSSTT" %in% names(adsl)) {
    return(basic_table() %>% build_table(data.frame(note = "EOSSTT not in ADSL")))
  }
  basic_table(show_colcounts = TRUE) %>%
    split_cols_by("ARM") %>%
    analyze_vars("EOSSTT", var_labels = c(EOSSTT = "End of study status")) %>%
    build_table(adsl)
}

build_lbt09_summary <- function(data) {
  adlb <- data[["ADLB"]]
  adsl <- data[["ADSL"]]
  alt <- adlb %>% filter(grepl("Alanine", .data$PARAM, ignore.case = TRUE))
  if (nrow(alt) == 0L) {
    return(basic_table() %>% build_table(data.frame(note = "ALT parameter not found")))
  }
  basic_table(show_colcounts = TRUE) %>%
    split_cols_by("ARM") %>%
    analyze_num_patients(
      vars = "USUBJID",
      .stats = "unique",
      .labels = c(unique = "Subjects with post-baseline ALT evaluable")
    ) %>%
    build_table(alt, alt_counts_df = adsl)
}

aovt01_ref_armcd <- function(adqs) {
  armcd <- as.character(adqs$ARMCD)
  if ("Pbo" %in% armcd) return("Pbo")
  sort(unique(armcd))[1]
}

build_aovt01 <- function(data) {
  adqs <- data[["ADQS"]]
  adsl <- data[["ADSL"]]
  if (is.null(adqs) || nrow(adqs) == 0L) {
    return(basic_table() %>% build_table(data.frame(note = "No ADQS analysis data available.")))
  }

  covariates <- intersect(c("BASE", "STRATA1"), names(adqs))
  if (length(covariates) < 2L) {
    return(basic_table() %>% build_table(data.frame(
      note = "ADQS is missing BASE and/or STRATA1 for ANCOVA."
    )))
  }

  if (requireNamespace("formatters", quietly = TRUE)) {
    labs <- formatters::var_labels(adqs)
    labs[["PARAMCD"]] <- "Parameter"
    formatters::var_labels(adqs) <- labs
  }

  ref_arm <- aovt01_ref_armcd(adqs)
  split_fun <- drop_split_levels

  basic_table() %>%
    split_cols_by("ARMCD", ref_group = ref_arm) %>%
    split_rows_by(
      "PARAMCD",
      split_fun = split_fun,
      label_pos = "topleft",
      split_label = obj_label(adqs$PARAMCD)
    ) %>%
    summarize_ancova(
      vars = "CHG",
      variables = list(
        arm = "ARMCD",
        covariates = covariates
      ),
      conf_level = 0.95,
      var_labels = "Adjusted mean"
    ) %>%
    build_table(adqs, alt_counts_df = adsl)
}

tlg_tern_module <- function(entry) {
  switch(entry$code,
    DMT01 = tern_table_module(entry, build_dmt01, "ADSL"),
    DST01 = tern_table_module(entry, build_dst01, "ADSL"),
    LBT09 = tern_table_module(entry, build_lbt09_summary, c("ADSL", "ADLB")),
    tlg_unavailable_module(entry)
  )
}
