# tern/rtables layouts ported from TLG Catalog (CDISCPILOT01 variable mapping).

suppressPackageStartupMessages({
  library(tern)
  library(rtables)
  library(dplyr)
})

tern_table_module <- function(entry, build_fun, datanames = "ADSL") {
  label <- tlg_module_label(entry)
  teal::module(
    label = label,
    server = function(id, data, ...) {
      moduleServer(id, function(input, output, session) {
        output$table <- renderUI({
          df <- data()
          tbl <- build_fun(df)
          table_inset(tbl, colgap = "5px")
        })
      })
    },
    ui = function(id, ...) {
      ns <- NS(id)
      tagList(
        h4(label),
        uiOutput(ns("table"))
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

tlg_tern_module <- function(entry) {
  switch(entry$code,
    DMT01 = tern_table_module(entry, build_dmt01, "ADSL"),
    DST01 = tern_table_module(entry, build_dst01, "ADSL"),
    LBT09 = tern_table_module(entry, build_lbt09_summary, c("ADSL", "ADLB")),
    tlg_unavailable_module(entry)
  )
}
