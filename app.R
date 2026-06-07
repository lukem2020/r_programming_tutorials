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
            "ae_analysis.R", "lab_analysis.R", "patient_profile.R")) {
  source(file.path(.root, "R", f))
}

study   <- load_study_data(.root)
cfg     <- study$config
ADSL    <- study$ADSL
ADAE    <- study$ADAE
ADLB    <- study$ADLB
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
    .stf-note { color:#555; font-size:12px; margin:-6px 0 14px 0; }
    .app-header { padding:10px 0 4px 0; }
    .app-header h2 { margin:0; }
    .app-sub { color:#666; }
  "))),
  div(class = "app-header",
      h2("Medical Data Review - Safety Dashboard"),
      div(class = "app-sub",
          sprintf("%s (%s) | Safety population N = %s | FDA ST&F: %s",
                  cfg$study$title, cfg$study$id,
                  cfg$study$n_subjects_safety, cfg$study$fda_stf_version))),
  hr(),
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
      selectInput("subject", "Subject (USUBJID):", choices = SUBJECTS),
      fluidRow(
        column(5, h4("Demographics"), DTOutput("pp_demo")),
        column(7, h4("Liver chemistry over time"), plotOutput("pp_lab", height = "320px"))
      ),
      br(),
      h4("Treatment-emergent adverse event timeline"),
      DTOutput("pp_ae")
    )
  )
)

# ---- Server ------------------------------------------------------------------
server <- function(input, output, session) {

  dt <- function(df, ...) datatable(df, rownames = FALSE,
                                    options = list(dom = "tip", pageLength = 15, ...),
                                    selection = "none")

  output$demo_tbl        <- renderDT(dt(demographics_table(ADSL, cfg)))
  output$disp_tbl        <- renderDT(dt(disposition_table(ADSL, cfg)))
  output$ae_overview_tbl <- renderDT(dt(ae_overview_table(ADAE, ADSL, cfg)))
  output$sae_tbl         <- renderDT(dt(sae_listing(ADAE, ADSL, cfg)))

  output$teae_plot <- renderPlot(teae_top_plot(ADAE, ADSL, cfg))
  output$soc_pt_tbl <- renderDT(dt(soc_pt_table(ADAE, ADSL, cfg)))

  output$lab_ct_plot <- renderPlot(
    lab_central_tendency_plot(ADLB, cfg, input$lab_param_ct))

  output$shift_tbl <- renderDT(
    dt(lab_shift_table(ADLB, cfg, input$lab_param_shift)))

  output$hys_plot <- renderPlot(hys_law_plot(ADLB, cfg))
  output$hys_tbl <- renderDT({
    hd <- hys_law_data(ADLB, cfg) %>%
      filter(.data$potential_hys_law) %>%
      transmute(USUBJID = .data$USUBJID, Arm = as.character(.data$ARM),
                `Max ALT (x ULN)` = round(.data$alt_uln, 2),
                `Max Bilirubin (x ULN)` = round(.data$bili_uln, 2))
    dt(hd)
  })

  output$pp_demo <- renderDT(dt(patient_demographics(ADSL, input$subject)))
  output$pp_ae   <- renderDT(dt(patient_ae_timeline(ADAE, input$subject)))
  output$pp_lab  <- renderPlot(patient_lab_plot(ADLB, cfg, input$subject))
}

shinyApp(ui, server)
