# TLG Catalog-style layout helpers (insightsengineering/tlg-catalog navigation pattern).

tlg_catalog_items <- function() {
  list(
    tables = list(
      list(id = "dmt01", code = "DMT01", title = "Demographics and Baseline Characteristics", section = "S1"),
      list(id = "dst01", code = "DST01", title = "Patient Disposition", section = "S2"),
      list(id = "ext01", code = "EXT01", title = "Study Drug Exposure", section = "S11"),
      list(id = "aet01", code = "AET01", title = "Safety Summary", section = "S3"),
      list(id = "aet02", code = "AET02", title = "Adverse Events by SOC and PT", section = "S5"),
      list(id = "aet03", code = "AET03", title = "Adverse Events by Greatest Intensity", section = "S5b"),
      list(id = "lbt04", code = "LBT04", title = "Laboratory Abnormalities Not Present at Baseline", section = "S7"),
      list(id = "cmt01", code = "CMT01", title = "Concomitant Medications by Class and Preferred Name", section = "S13")
    ),
    listings = list(
      list(id = "ael03", code = "AEL03", title = "Listing of Serious Adverse Events", section = "S4"),
      list(id = "cml01", code = "CML01", title = "Listing of Previous and Concomitant Medications", section = "S13"),
      list(id = "exl01", code = "EXL01", title = "Listing of Exposure to Study Drug", section = "S11")
    ),
    graphs = list(
      list(id = "lbt01", code = "LBT01", title = "Laboratory Results and Change from Baseline by Visit", section = "S6"),
      list(id = "lbt09", code = "LBT09", title = "Hepatic Safety / Hy's Law (eDISH)", section = "S8"),
      list(id = "vst01", code = "VST01", title = "Vital Sign Results and Change from Baseline by Visit", section = "S12"),
      list(id = "kmg01", code = "KMG01", title = "Kaplan-Meier Plot", section = "S10"),
      list(id = "aet02g", code = "AET02", title = "Top Treatment-Emergent AEs (incidence)", section = "S5"),
      list(id = "corr01", code = "Custom", title = "Safety Parameter Correlation", section = "S14")
    )
  )
}

tlg_section_meta <- function(cfg, section_id) {
  Filter(function(x) identical(x$id, section_id), cfg$safety_review_sections)[[1]]
}

tlg_page_header <- function(code, title, section_id, cfg) {
  s <- tlg_section_meta(cfg, section_id)
  tagList(
    div(
      class = "tlg-page-header",
      span(class = "tlg-code", code),
      span(class = "tlg-page-title", title)
    ),
    div(
      class = "stf-note",
      sprintf(
        "FDA ST&F: %s | Dataset: %s | Safety population: %s == 'Y'",
        s$fda_stf, s$dataset, cfg$analysis_population$safety_population_flag
      )
    )
  )
}

tlg_nav_choices <- function(items) {
  stats::setNames(
    vapply(items, function(x) x$id, character(1)),
    vapply(items, function(x) sprintf("%s — %s", x$code, x$title), character(1))
  )
}

tlg_nav_sidebar <- function(input_id, category, items) {
  tagList(
    div(class = "tlg-nav-category", category),
    radioButtons(
      input_id,
      label = NULL,
      choices = tlg_nav_choices(items),
      selected = items[[1]]$id
    )
  )
}

tlg_global_header <- function(cfg, arm_choices) {
  tagList(
    div(
      class = "tlg-study-banner",
      div(
        class = "tlg-study-title",
        "Medical Data Review — TLG Catalog Layout"
      ),
      div(
        class = "tlg-study-meta",
        sprintf(
          "%s (%s) | Safety N = %s | FDA ST&F: %s",
          cfg$study$title,
          cfg$study$id,
          cfg$study$n_subjects_safety,
          cfg$study$fda_stf_version
        )
      )
    ),
    div(
      class = "tlg-global-filters",
      fluidRow(
        column(
          12,
          checkboxGroupInput(
            "arm_filter",
            "Treatment arms (applies to all TLGs):",
            choices = arm_choices,
            selected = arm_choices,
            inline = TRUE
          )
        )
      )
    )
  )
}

tlg_catalog_css <- function() {
  HTML("
    body { background:#f4f6f8; color:#1f2d3d;
           font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif; }
    .navbar-default { background:#1f2d3d !important; border:none;
                      box-shadow:0 1px 3px rgba(31,45,61,0.18); }
    .navbar-default .navbar-brand,
    .navbar-default .navbar-nav > li > a { color:#e8eef4 !important; font-weight:500; }
    .navbar-default .navbar-nav > .active > a,
    .navbar-default .navbar-nav > .active > a:focus,
    .navbar-default .navbar-nav > .active > a:hover {
      background:#2a3f54 !important; color:#fff !important; }
    .navbar-default .navbar-brand { font-weight:600; font-size:17px; }
    .navbar-brand .brand-sub { display:block; font-size:11px; font-weight:400;
                               color:#aebccb; margin-top:2px; }
    .tlg-shell { margin-top:14px; }
    .tlg-sidebar { background:#fff; border:1px solid #e3e8ec; border-radius:8px;
                   padding:14px 12px; box-shadow:0 1px 3px rgba(31,45,61,0.06); }
    .tlg-study-banner { background:#1f2d3d; color:#fff; padding:14px 20px; margin:12px 15px 0 15px;
                        border-radius:8px; }
    .tlg-study-title { font-size:18px; font-weight:600; }
    .tlg-study-meta { color:#aebccb; font-size:12px; margin-top:4px; }
    .tlg-global-filters { background:#fff; border:1px solid #e3e8ec; border-radius:8px;
                           margin:10px 15px 0 15px; padding:8px 16px 2px 16px; }
    .tlg-global-filters .control-label { font-weight:600; font-size:13px; }
    .tlg-nav-category { font-size:11px; font-weight:700; letter-spacing:0.6px;
                        text-transform:uppercase; color:#5b6770; margin:4px 0 8px 2px; }
    .tlg-sidebar .radio { margin-top:0; }
    .tlg-sidebar .radio label { font-size:12px; line-height:1.35; color:#41525f;
                               padding:6px 8px 6px 24px; border-radius:4px; width:100%; }
    .tlg-sidebar .radio label:hover { background:#eef3f8; }
    .tlg-sidebar .radio input[type='radio'] { margin-top:3px; }
    .tlg-main { background:#fff; border:1px solid #e3e8ec; border-radius:8px;
                padding:20px 24px 26px 24px;
                box-shadow:0 1px 3px rgba(31,45,61,0.06); min-height:520px; }
    .tlg-page-header { margin-bottom:10px; }
    .tlg-code { display:inline-block; background:#1f6fb2; color:#fff; font-size:12px;
                font-weight:700; padding:3px 9px; border-radius:4px; margin-right:10px; }
    .tlg-page-title { font-size:18px; font-weight:600; color:#1f2d3d; }
    .stf-note { color:#41525f; font-size:12px; background:#eef3f8;
                border-left:3px solid #1f6fb2; padding:7px 11px; border-radius:4px;
                margin:0 0 16px 0; line-height:1.5; }
    h4 { font-size:15px; font-weight:600; color:#1f2d3d; margin-top:8px; margin-bottom:10px; }
    table.dataTable thead th { background:#f4f6f8; color:#1f2d3d;
                              border-bottom:2px solid #dde3e8; font-weight:600; }
  ")
}

tlg_catalog_page <- function(input_id, category, items, content) {
  fluidRow(
    class = "tlg-shell",
    column(
      3,
      div(class = "tlg-sidebar", tlg_nav_sidebar(input_id, category, items))
    ),
    column(9, div(class = "tlg-main", content))
  )
}
