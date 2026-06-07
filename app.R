# MDR Safety Dashboard - CDISCPILOT01
# Structured to the FDA Standard Safety Tables and Figures (ST&F) Integrated Guide
# and the pharmaverse TLG Catalog. Reads config/study_config.yml and data/adam/.
#
# Run locally:   shiny::runApp(".")
# Deploy:        rsconnect::deployApp(appDir = ".",
#                  appFiles = c("app.R", "R/", "config/", "data/adam/"))

suppressPackageStartupMessages({
  library(shiny)
  library(DT)
  library(ggplot2)
  library(dplyr)
})

# ---- Load helpers + data -----------------------------------------------------
.root <- local({
  d <- normalizePath(getwd(), winslash = "/", mustWork = FALSE)
  repeat {
    if (file.exists(file.path(d, "config", "study_config.yml"))) break
    p <- dirname(d); if (identical(p, d)) break; d <- p
  }
  d
})
for (f in c("load_data.R", "theme_clinical.R", "demographics.R",
            "ae_analysis.R", "lab_analysis.R", "patient_profile.R",
            "tte_analysis.R")) {
  source(file.path(.root, "R", f))
}

study   <- load_study_data(.root)
cfg     <- study$config
ADSL    <- study$ADSL
ADAE    <- study$ADAE
ADLB    <- study$ADLB
ADTTE   <- study$ADTTE
LIVER   <- liver_params(cfg)
SUBJECTS <- profile_subject_choices(ADSL, cfg)

section_label <- function(id) {
  s <- Filter(function(x) x$id == id, cfg$safety_review_sections)[[1]]
  sprintf("%s | FDA ST&F: %s | TLG: %s", s$title, s$fda_stf, s$tlg_ref)
}

# ---- UI ----------------------------------------------------------------------
ui <- fluidPage(
  title = "MDR Safety Dashboard",
  tags$head(tags$style(HTML("
    body { background:#f4f6f8; color:#1f2d3d;
           font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif; }
    .container-fluid { max-width:1200px; }
    .app-header { background:#1f2d3d; color:#fff; padding:18px 24px;
                  border-radius:8px; margin-top:14px;
                  box-shadow:0 1px 3px rgba(31,45,61,0.18); }
    .app-header h2 { margin:0; font-weight:600; font-size:22px; letter-spacing:0.2px; }
    .app-header .app-sub { color:#aebccb; font-size:13px; margin-top:6px; }
    .app-header .app-pop { display:inline-block; background:rgba(255,255,255,0.12);
                  color:#e8eef4; font-size:12px; padding:2px 9px; border-radius:12px;
                  margin-right:8px; }
    .nav-tabs { border-bottom:2px solid #dde3e8; margin-top:20px; }
    .nav-tabs > li > a { color:#5b6770; font-weight:500; border:none !important;
                  background:transparent !important; padding:9px 15px; }
    .nav-tabs > li > a:hover { color:#1f6fb2; background:#eef3f7 !important;
                  border-radius:5px 5px 0 0; }
    .nav-tabs > li.active > a, .nav-tabs > li.active > a:focus {
                  color:#1f6fb2 !important; border:none !important;
                  border-bottom:3px solid #1f6fb2 !important; background:transparent !important; }
    .tab-content { background:#fff; border:1px solid #e3e8ec; border-top:none;
                  padding:20px 24px 26px 24px; border-radius:0 0 8px 8px;
                  box-shadow:0 1px 3px rgba(31,45,61,0.06); }
    .stf-note { color:#41525f; font-size:12px; background:#eef3f8;
                  border-left:3px solid #1f6fb2; padding:7px 11px; border-radius:4px;
                  margin:0 0 16px 0; line-height:1.5; }
    h4 { font-size:15px; font-weight:600; color:#1f2d3d; margin-top:8px; margin-bottom:10px; }
    .selectize-input, .form-control { border-radius:5px; border-color:#cfd7de; }
    table.dataTable thead th { background:#f4f6f8; color:#1f2d3d;
                  border-bottom:2px solid #dde3e8; font-weight:600; }
    .dataTables_filter input { border:1px solid #cfd7de; border-radius:5px;
                  padding:3px 8px; }
  "))),
  div(class = "app-header",
      h2("Medical Data Review \u2013 Safety Dashboard"),
      div(class = "app-sub",
          span(class = "app-pop", sprintf("Safety N = %s", cfg$study$n_subjects_safety)),
          sprintf("%s (%s) | FDA ST&F: %s",
                  cfg$study$title, cfg$study$id, cfg$study$fda_stf_version))),
  tabsetPanel(
    type = "tabs",

    tabPanel(
      "Demographics",
      br(),
      div(class = "stf-note", section_label("S1")),
      h4("Demographics and baseline characteristics"),
      DTOutput("demo_tbl"),
      br(),
      div(class = "stf-note", section_label("S2")),
      h4("Patient disposition"),
      DTOutput("disp_tbl")
    ),

    tabPanel(
      "AE Overview",
      br(),
      div(class = "stf-note", section_label("S3")),
      h4("Overview of adverse events"),
      DTOutput("ae_overview_tbl"),
      br(),
      div(class = "stf-note", section_label("S4")),
      h4("Serious adverse events"),
      DTOutput("sae_tbl")
    ),

    tabPanel(
      "TEAE Table",
      br(),
      div(class = "stf-note", section_label("S5")),
      plotOutput("teae_plot", height = "460px"),
      br(),
      h4("Treatment-emergent AEs by SOC and preferred term (subject counts)"),
      DTOutput("soc_pt_tbl")
    ),

    tabPanel(
      "Lab Trends",
      br(),
      div(class = "stf-note", section_label("S6")),
      selectInput("lab_param_ct", "Laboratory parameter:",
                  choices = LIVER, selected = unname(LIVER["ALT"])),
      plotOutput("lab_ct_plot", height = "460px")
    ),

    tabPanel(
      "Lab Shifts",
      br(),
      div(class = "stf-note", section_label("S7")),
      selectInput("lab_param_shift", "Laboratory parameter:",
                  choices = LIVER, selected = unname(LIVER["ALT"])),
      h4("Baseline to worst post-baseline shift (subject counts by arm)"),
      DTOutput("shift_tbl")
    ),

    tabPanel(
      "Hy's Law",
      br(),
      div(class = "stf-note", section_label("S8")),
      plotOutput("hys_plot", height = "500px"),
      br(),
      h4("Subjects in the Hy's Law zone"),
      DTOutput("hys_tbl")
    ),

    tabPanel(
      "Patient Profile",
      br(),
      div(class = "stf-note", section_label("S9")),
      selectizeInput("subject", "Search subject (USUBJID):", choices = SUBJECTS,
                     width = "340px",
                     options = list(placeholder = "Type to search a subject...",
                                    maxOptions = 2000)),
      fluidRow(
        column(5, h4("Demographics"), DTOutput("pp_demo")),
        column(7, h4("Liver chemistry over time"), plotOutput("pp_lab", height = "320px"))
      ),
      br(),
      h4("Treatment-emergent adverse event timeline"),
      DTOutput("pp_ae")
    ),

    tabPanel(
      "Time-to-Event",
      br(),
      div(class = "stf-note", section_label("S10")),
      plotOutput("km_plot", height = "480px"),
      div(
        class = "stf-note",
        style = "margin-top:8px;",
        p(strong("Time to first application-site reaction by arm."),
          " The patch arms separate early from placebo - a tolerability signal ",
          "visualised as a Kaplan-Meier curve, with a log-rank test and median ",
          "time-to-event. The event is derived into a CDISC ADTTE dataset, the ",
          "same structure a statistical programmer would hand off."),
        p(em("Event = first treatment-emergent application-site / skin AE; ",
             "subjects with no event are censored at end of treatment (TRTDURD)."))
      ),
      br(),
      h4("Median time to first dermatologic event (log-rank across arms)"),
      DTOutput("km_median")
    )
  )
)

# ---- Server ------------------------------------------------------------------
server <- function(input, output, session) {

  # Searchable, lightly styled tables. `searchable` toggles the filter box so
  # subject-level listings (SAEs, SOC/PT, AE timeline, Hy's Law) can be searched.
  dt <- function(df, searchable = TRUE, ...) datatable(
    df, rownames = FALSE,
    class = "stripe hover row-border compact",
    options = list(
      dom = if (searchable) "ftip" else "tip",
      pageLength = 15,
      searchHighlight = TRUE,
      language = list(search = "Filter:", searchPlaceholder = "type to search..."),
      ...
    ),
    selection = "none")

  output$demo_tbl        <- renderDT(dt(demographics_table(ADSL, cfg), searchable = FALSE))
  output$disp_tbl        <- renderDT(dt(disposition_table(ADSL, cfg), searchable = FALSE))
  output$ae_overview_tbl <- renderDT(dt(ae_overview_table(ADAE, ADSL, cfg), searchable = FALSE))
  output$sae_tbl         <- renderDT(dt(sae_listing(ADAE, ADSL, cfg)))

  output$teae_plot <- renderPlot(teae_top_plot(ADAE, ADSL, cfg))
  output$soc_pt_tbl <- renderDT(dt(soc_pt_table(ADAE, ADSL, cfg)))

  output$lab_ct_plot <- renderPlot(
    lab_central_tendency_plot(ADLB, cfg, input$lab_param_ct))

  output$shift_tbl <- renderDT(
    dt(lab_shift_table(ADLB, cfg, input$lab_param_shift), searchable = FALSE))

  output$hys_plot <- renderPlot(hys_law_plot(ADLB, cfg))
  output$hys_tbl <- renderDT({
    hd <- hys_law_data(ADLB, cfg) %>%
      filter(.data$potential_hys_law) %>%
      transmute(USUBJID = .data$USUBJID, Arm = as.character(.data$ARM),
                `Max ALT (x ULN)` = round(.data$alt_uln, 2),
                `Max Bilirubin (x ULN)` = round(.data$bili_uln, 2))
    dt(hd)
  })

  output$pp_demo <- renderDT(dt(patient_demographics(ADSL, input$subject), searchable = FALSE))
  output$pp_ae   <- renderDT(dt(patient_ae_timeline(ADAE, input$subject)))
  output$pp_lab  <- renderPlot(patient_lab_plot(ADLB, cfg, input$subject))

  output$km_plot   <- renderPlot({
    validate(need(!is.null(ADTTE), "ADTTE not found - run programs/02_derive_adtte.R"))
    km_plot(ADTTE, cfg)
  })
  output$km_median <- renderDT({
    validate(need(!is.null(ADTTE), "ADTTE not found - run programs/02_derive_adtte.R"))
    dt(km_median_table(ADTTE, cfg), searchable = FALSE)
  })
}

shinyApp(ui, server)
