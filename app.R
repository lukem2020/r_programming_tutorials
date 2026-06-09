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
for (f in c("load_data.R", "theme_clinical.R", "visit_aggregation.R", "trend_regression.R",
            "demographics.R", "exposure_analysis.R", "ae_analysis.R", "lab_analysis.R",
            "vs_analysis.R", "cm_analysis.R", "patient_profile.R", "tte_analysis.R",
            "correlation_analysis.R")) {
  source(file.path(.root, "R", f))
}

study    <- load_study_data(.root)
cfg      <- study$config
ADSL     <- study$ADSL
ADAE     <- study$ADAE
ADLB     <- study$ADLB
ADTTE    <- study$ADTTE
ADEX     <- study$ADEX
ADVS     <- study$ADVS
ADCM     <- study$ADCM
ADMH     <- study$ADMH
LAB_CAT  <- lab_param_catalog(ADLB)
LAB_CHOICES <- LAB_CAT$by_category
LAB_SHIFT_CHOICES <- LAB_CAT$shift_by_category
DEFAULT_LAB <- default_lab_param(cfg, LAB_CAT)
VS_PARAMS <- if (!is.null(ADVS)) vs_param_choices(cfg, ADVS) else character()
SUBJECTS <- profile_subject_choices(ADSL, cfg)
ARM_CHOICES <- arm_levels(cfg)
TTE_ENDPOINTS <- tte_all_endpoint_choices(cfg, ADAE, ADSL)
DEFAULT_TTE <- TTE_ENDPOINTS[[1]]

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
    .container-fluid { max-width:1320px; }
    .app-header { background:#1f2d3d; color:#fff; padding:18px 24px;
                  border-radius:8px; margin-top:14px;
                  box-shadow:0 1px 3px rgba(31,45,61,0.18); }
    .app-header h2 { margin:0; font-weight:600; font-size:22px; letter-spacing:0.2px; }
    .app-header .app-sub { color:#aebccb; font-size:13px; margin-top:6px; }
    .app-header .app-pop { display:inline-block; background:rgba(255,255,255,0.12);
                  color:#e8eef4; font-size:12px; padding:2px 9px; border-radius:12px;
                  margin-right:8px; }
  "))),
  div(class = "app-header",
      h2("Medical Data Review \u2013 Safety Dashboard"),
      div(class = "app-sub",
          span(class = "app-pop", sprintf("Safety N = %s", cfg$study$n_subjects_safety)),
          sprintf("%s (%s) | FDA ST&F: %s",
                  cfg$study$title, cfg$study$id, cfg$study$fda_stf_version))),
  sidebarLayout(
    sidebarPanel(
      width = 3,
      h4("Filters"),
      helpText("Safety population fixed at SAFFL == 'Y'."),
      checkboxGroupInput("arm_filter", "Treatment arms:",
                         choices = ARM_CHOICES, selected = ARM_CHOICES),
      hr(),
      helpText("Teal-equivalent filter panel: arm selection applies across all modules.")
    ),
    mainPanel(
      width = 9,
      tags$head(tags$style(HTML("
        .nav-tabs { border-bottom:2px solid #dde3e8; margin-top:12px; }
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
        table.dataTable thead th { background:#f4f6f8; color:#1f2d3d;
                      border-bottom:2px solid #dde3e8; font-weight:600; }
      "))),
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
          DTOutput("disp_tbl"),
          br(),
          div(class = "stf-note", section_label("S11")),
          h4("Treatment exposure summary"),
          DTOutput("exposure_summary_tbl"),
          br(),
          h4("Exposure record detail (ADEX)"),
          DTOutput("exposure_detail_tbl")
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
          DTOutput("soc_pt_tbl"),
          br(),
          div(class = "stf-note", section_label("S5b")),
          h4("Treatment-emergent AEs by SOC, PT and severity (AET03)"),
          DTOutput("teae_sev_tbl")
        ),

        tabPanel(
          "Lab Trends",
          br(),
          div(class = "stf-note", section_label("S6")),
          radioButtons("lab_value_type", "Display:",
                       choices = c("Absolute value (AVAL)" = "aval",
                                   "Change from baseline (CHG)" = "chg"),
                       selected = "aval", inline = TRUE),
          selectInput("lab_param_ct", "Laboratory parameter:",
                      choices = LAB_CHOICES, selected = DEFAULT_LAB),
          helpText(sprintf("%d parameters across %d categories (all ADLB PARAM values).",
                           length(unique(unlist(LAB_CHOICES))), length(LAB_CHOICES))),
          plotOutput("lab_ct_plot", height = "460px")
        ),

        tabPanel(
          "Lab Shifts",
          br(),
          div(class = "stf-note", section_label("S7")),
          selectInput("lab_param_shift", "Laboratory parameter:",
                      choices = LAB_SHIFT_CHOICES, selected = DEFAULT_LAB),
          helpText("Parameters with BNRIND/ANRIND shift data at post-baseline visits."),
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
          "Vital Signs",
          br(),
          div(class = "stf-note", section_label("S12")),
          selectInput("vs_param", "Vital sign parameter:",
                      choices = VS_PARAMS,
                      selected = if (length(VS_PARAMS) > 0) VS_PARAMS[1] else NULL),
          plotOutput("vs_plot", height = "460px")
        ),

        tabPanel(
          "Concomitant Meds",
          br(),
          div(class = "stf-note", section_label("S13")),
          h4("On-treatment concomitant medications summary"),
          DTOutput("cm_summary_tbl"),
          br(),
          h4("Concomitant medication listing"),
          DTOutput("cm_listing_tbl")
        ),

        tabPanel(
          "Patient Profile",
          br(),
          div(class = "stf-note", section_label("S9")),
          fluidRow(
            column(
              4,
              wellPanel(
                checkboxInput(
                  "pp_completed_only",
                  "Completed trial only",
                  value = FALSE
                ),
                helpText(
                  sprintf("When checked, subject list is limited to %s = '%s'.",
                          cfg$patient_profile$disposition_variable,
                          cfg$patient_profile$completed_eosstt)
                ),
                textOutput("pp_subject_count")
              )
            ),
            column(
              8,
              selectizeInput(
                "subject", "Search subject (USUBJID):",
                choices = SUBJECTS, selected = SUBJECTS[1],
                width = "100%",
                options = list(
                  placeholder = "Type to search a subject...",
                  maxOptions = 2000
                )
              )
            )
          ),
          fluidRow(
            column(12, h4("Demographics"), DTOutput("pp_demo"))
          ),
          br(),
          h4("Laboratory results"),
          helpText("Full ADLB listing for this subject (searchable)."),
          DTOutput("pp_lab_tbl"),
          br(),
          h4("Laboratory panels over time"),
          helpText("Faceted trend plots: hepatic, chemistry, haematology, and urinalysis panels."),
          uiOutput("pp_lab_panels_ui"),
          br(),
          h4("Vital signs over time"),
          helpText("All trend-plottable vital signs for this subject (height is screening-only and omitted)."),
          uiOutput("pp_vs_ui"),
          br(),
          h4("Medical history"),
          DTOutput("pp_mh"),
          br(),
          h4("On-treatment concomitant medications"),
          DTOutput("pp_cm"),
          br(),
          h4("Treatment-emergent adverse event timeline"),
          DTOutput("pp_ae")
        ),

        tabPanel(
          "Time-to-Event",
          br(),
          div(class = "stf-note", section_label("S10")),
          selectInput(
            "tte_endpoint", "Time-to-event endpoint:",
            choices = TTE_ENDPOINTS, selected = DEFAULT_TTE
          ),
          plotOutput("km_plot", height = "480px"),
          div(
            class = "stf-note",
            style = "margin-top:8px;",
            p(strong("Kaplan-Meier curves by treatment arm."),
              " Log-rank test and median time-to-event table below."),
            p(em("Subjects without the selected event are censored at end of treatment (TRTDURD)."))
          ),
          br(),
          h4("Median time to event (log-rank across arms)"),
          DTOutput("km_median")
        ),

        tabPanel(
          "Correlation",
          br(),
          div(class = "stf-note", section_label("S14")),
          helpText(
            "Spearman rank correlation of max post-baseline laboratory and vital sign ",
            "values within each treatment arm (pairwise complete observations)."
          ),
          uiOutput("corr_plots_ui"),
          br(),
          h4("Correlation matrices (numeric)"),
          uiOutput("corr_tables_ui")
        )
      )
    )
  )
)

# ---- Server ------------------------------------------------------------------
server <- function(input, output, session) {

  selected_arms <- reactive({
    arms <- input$arm_filter
    if (is.null(arms) || length(arms) == 0) ARM_CHOICES else arms
  })

  dt <- function(df, searchable = TRUE, ...) datatable(
    df, rownames = FALSE,
    class = "stripe hover row-border compact",
    options = list(
      dom = if (searchable) "ftip" else "tip",
      pageLength = 15,
      searchHighlight = TRUE,
      language = list(search = "Filter:", searchPlaceholder = "type to search..."),
      scrollX = TRUE,
      ...
    ),
    selection = "none")

  output$demo_tbl <- renderDT({
    dt(demographics_table(ADSL, cfg, selected_arms()), searchable = FALSE)
  })
  output$disp_tbl <- renderDT({
    dt(disposition_table(ADSL, cfg, selected_arms()), searchable = FALSE)
  })
  output$exposure_summary_tbl <- renderDT({
    dt(exposure_summary_table(ADSL, cfg, selected_arms()), searchable = FALSE)
  })
  output$exposure_detail_tbl <- renderDT({
    dt(exposure_detail_table(ADEX, ADSL, cfg, selected_arms()), searchable = FALSE)
  })

  output$ae_overview_tbl <- renderDT({
    dt(ae_overview_table(ADAE, ADSL, cfg, selected_arms()), searchable = FALSE)
  })
  output$sae_tbl <- renderDT({
    dt(sae_listing(ADAE, ADSL, cfg, selected_arms()))
  })

  output$teae_plot <- renderPlot({
    teae_top_plot(ADAE, ADSL, cfg, arms = selected_arms())
  })
  output$soc_pt_tbl <- renderDT({
    dt(soc_pt_table(ADAE, ADSL, cfg, selected_arms()))
  })
  output$teae_sev_tbl <- renderDT({
    dt(teae_severity_table(ADAE, ADSL, cfg, selected_arms()))
  })

  output$lab_ct_plot <- renderPlot({
    arms <- selected_arms()
    if (identical(input$lab_value_type, "chg")) {
      lab_change_from_baseline_plot(ADLB, cfg, input$lab_param_ct, arms)
    } else {
      lab_central_tendency_plot(ADLB, cfg, input$lab_param_ct, arms)
    }
  })

  output$shift_tbl <- renderDT({
    dt(lab_shift_table(ADLB, cfg, input$lab_param_shift, selected_arms()),
       searchable = FALSE)
  })

  output$hys_plot <- renderPlot(hys_law_plot(ADLB, cfg))
  output$hys_tbl <- renderDT({
    hd <- hys_law_data(ADLB, cfg) %>%
      filter(.data$potential_hys_law) %>%
      filter(.data$ARM %in% selected_arms()) %>%
      transmute(USUBJID = .data$USUBJID, Arm = as.character(.data$ARM),
                `Max ALT (x ULN)` = round(.data$alt_uln, 2),
                `Max Bilirubin (x ULN)` = round(.data$bili_uln, 2))
    dt(hd)
  })

  output$vs_plot <- renderPlot({
    validate(need(!is.null(ADVS), "ADVS not found — run programs/01_prepare_adam.R"))
    vs_central_tendency_plot(ADVS, cfg, input$vs_param, selected_arms())
  })

  output$cm_summary_tbl <- renderDT({
    dt(cm_summary_table(ADCM, ADSL, cfg, selected_arms()), searchable = FALSE)
  })
  output$cm_listing_tbl <- renderDT({
    dt(cm_listing(ADCM, ADSL, cfg, selected_arms()))
  })

  observeEvent(input$pp_completed_only, {
    subjects <- profile_subject_choices(ADSL, cfg, isTRUE(input$pp_completed_only))
    selected <- input$subject
    if (is.null(selected) || length(selected) == 0L || !(selected %in% subjects)) {
      selected <- if (length(subjects) > 0L) subjects[[1]] else NULL
    }
    updateSelectizeInput(session, "subject", choices = subjects, selected = selected)
  }, ignoreInit = TRUE)

  output$pp_subject_count <- renderText({
    n_show <- length(profile_subject_choices(ADSL, cfg, isTRUE(input$pp_completed_only)))
    n_all <- length(profile_subject_choices(ADSL, cfg, completed_only = FALSE))
    if (isTRUE(input$pp_completed_only)) {
      sprintf("Showing %d completed subjects (of %d in safety population).", n_show, n_all)
    } else {
      sprintf("Showing all %d safety subjects.", n_show)
    }
  })

  output$pp_lab_panels_ui <- renderUI({
    req(input$subject)
    panels <- patient_lab_panels_for_subject(ADLB, cfg, input$subject)
    if (length(panels) == 0) {
      return(helpText("No plottable laboratory panels for this subject."))
    }
    tagList(lapply(panels, function(panel) {
      tagList(
        h4(panel$title),
        plotOutput(
          paste0("pp_lab_panel_", panel$id),
          height = sprintf("%dpx", patient_lab_panel_height(panel$n_params))
        )
      )
    }))
  })

  observe({
    req(input$subject)
    panels <- patient_lab_panels_for_subject(ADLB, cfg, input$subject)
    for (panel in panels) {
      local({
        spec <- panel
        output[[paste0("pp_lab_panel_", spec$id)]] <- renderPlot({
          patient_lab_panel_trend_plot(ADLB, cfg, input$subject, spec)
        })
      })
    }
  })

  output$pp_demo <- renderDT({
    dt(patient_demographics(ADSL, input$subject), searchable = FALSE)
  })
  output$pp_ae <- renderDT({
    dt(patient_ae_timeline(ADAE, input$subject))
  })
  output$pp_lab_tbl <- renderDT({
    req(input$subject)
    datatable(
      patient_lab_table(ADLB, cfg, input$subject),
      rownames = FALSE,
      class = "stripe hover row-border compact",
      selection = "none",
      options = list(
        dom = "ftip",
        pageLength = 12,
        searchHighlight = TRUE,
        language = list(search = "Filter:", searchPlaceholder = "parameter, visit, range..."),
        scrollX = TRUE
      )
    )
  })
  output$pp_vs_ui <- renderUI({
    req(input$subject)
    if (is.null(ADVS)) {
      return(helpText("ADVS not found — run programs/01_prepare_adam.R"))
    }
    n_vs <- patient_vitals_panel_n_params(ADVS, input$subject)
    if (n_vs == 0L) {
      return(helpText("No plottable vital signs for this subject."))
    }
    plotOutput(
      "pp_vs",
      height = sprintf("%dpx", patient_vitals_panel_height(n_vs))
    )
  })

  output$pp_vs <- renderPlot({
    req(input$subject)
    patient_vitals_panel_plot(ADVS, input$subject)
  })
  output$pp_cm <- renderDT({
    dt(patient_cm_table(ADCM, cfg, input$subject))
  })
  output$pp_mh <- renderDT({
    dt(patient_mh_table(ADMH, input$subject), searchable = FALSE)
  })

  observe({
    choices <- tte_all_endpoint_choices(cfg, ADAE, ADSL, selected_arms())
    sel <- input$tte_endpoint
    if (is.null(sel) || !sel %in% choices) sel <- choices[[1]]
    updateSelectInput(session, "tte_endpoint", choices = choices, selected = sel)
  })

  output$km_plot <- renderPlot({
    req(input$tte_endpoint)
    if (!is_pt_endpoint(input$tte_endpoint)) {
      validate(need(!is.null(ADTTE), "ADTTE not found - run programs/02_derive_adtte.R"))
    }
    km_plot(ADTTE, cfg, input$tte_endpoint, ADSL, ADAE, selected_arms())
  })
  output$km_median <- renderDT({
    req(input$tte_endpoint)
    if (!is_pt_endpoint(input$tte_endpoint)) {
      validate(need(!is.null(ADTTE), "ADTTE not found - run programs/02_derive_adtte.R"))
    }
    dt(
      km_median_table(ADTTE, cfg, input$tte_endpoint, ADSL, ADAE, selected_arms()),
      searchable = FALSE
    )
  })

  corr_params <- reactive({
    correlation_parameters(cfg, ADLB, ADVS)
  })

  corr_wide <- reactive({
    params <- corr_params()
    validate(need(length(params) >= 2L, "Need at least 2 parameters for correlation"))
    subject_correlation_wide(ADLB, ADVS, ADSL, cfg, params, selected_arms())
  })

  output$corr_plots_ui <- renderUI({
    params <- corr_params()
    arms <- selected_arms()
    n <- length(params)
    validate(need(n >= 2L, "Need at least 2 parameters for correlation"))
    tagList(lapply(arms, function(arm) {
      tagList(
        plotOutput(
          paste0("corr_arm_", arm_slug(arm)),
          height = sprintf("%dpx", correlation_plot_height(n))
        ),
        br()
      )
    }))
  })

  output$corr_tables_ui <- renderUI({
    arms <- selected_arms()
    codes <- .param_codes(ADLB, ADVS, corr_params()) %>% pull(.data$PARAMCD)
    tagList(lapply(arms, function(arm) {
      tagList(
        h5(arm),
        DTOutput(paste0("corr_tbl_", arm_slug(arm))),
        br()
      )
    }))
  })

  observe({
    wide <- corr_wide()
    params <- corr_params()
    codes <- .param_codes(ADLB, ADVS, params) %>% pull(.data$PARAMCD)
    for (arm in selected_arms()) {
      local({
        a <- arm
        slug <- arm_slug(a)
        output[[paste0("corr_arm_", slug)]] <- renderPlot({
          mat <- spearman_correlation_matrix(wide, a, codes)
          spearman_correlation_heatmap(mat, a, cfg)
        })
        output[[paste0("corr_tbl_", slug)]] <- renderDT({
          dt(spearman_correlation_table(wide, a, codes), searchable = FALSE)
        })
      })
    }
  })
}

shinyApp(ui, server)
