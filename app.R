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
            "correlation_analysis.R", "tlg_layout.R")) {
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
TLG_NAV <- tlg_catalog_items()

# ---- UI ----------------------------------------------------------------------
ui <- navbarPage(
  id = "tlg_navbar",
  title = tagList(
    "TLG Safety Catalog",
    tags$span(class = "brand-sub", sprintf("%s | CDISCPILOT01 ADaM", cfg$study$drug))
  ),
  header = tagList(
    tags$head(tlg_catalog_css()),
    tlg_global_header(cfg, ARM_CHOICES)
  ),
  windowTitle = "MDR Safety Dashboard — TLG Catalog",

  tabPanel(
    "Tables",
    tlg_catalog_page(
      "tlg_tables",
      "Tables",
      TLG_NAV$tables,
      tagList(
        conditionalPanel(
          condition = "input.tlg_tables == 'dmt01'",
          tlg_page_header("DMT01", "Demographics and Baseline Characteristics", "S1", cfg),
          DTOutput("demo_tbl")
        ),
        conditionalPanel(
          condition = "input.tlg_tables == 'dst01'",
          tlg_page_header("DST01", "Patient Disposition", "S2", cfg),
          DTOutput("disp_tbl")
        ),
        conditionalPanel(
          condition = "input.tlg_tables == 'ext01'",
          tlg_page_header("EXT01", "Study Drug Exposure", "S11", cfg),
          h4("Exposure summary"),
          DTOutput("exposure_summary_tbl"),
          br(),
          h4("Exposure record detail (ADEX)"),
          DTOutput("exposure_detail_tbl")
        ),
        conditionalPanel(
          condition = "input.tlg_tables == 'aet01'",
          tlg_page_header("AET01", "Safety Summary", "S3", cfg),
          DTOutput("ae_overview_tbl")
        ),
        conditionalPanel(
          condition = "input.tlg_tables == 'aet02'",
          tlg_page_header("AET02", "Adverse Events by SOC and Preferred Term", "S5", cfg),
          DTOutput("soc_pt_tbl")
        ),
        conditionalPanel(
          condition = "input.tlg_tables == 'aet03'",
          tlg_page_header("AET03", "Adverse Events by Greatest Intensity", "S5b", cfg),
          DTOutput("teae_sev_tbl")
        ),
        conditionalPanel(
          condition = "input.tlg_tables == 'lbt04'",
          tlg_page_header("LBT04", "Laboratory Abnormalities Not Present at Baseline", "S7", cfg),
          selectInput("lab_param_shift", "Laboratory parameter:",
                      choices = LAB_SHIFT_CHOICES, selected = DEFAULT_LAB),
          helpText("Parameters with BNRIND/ANRIND shift data at post-baseline visits."),
          DTOutput("shift_tbl")
        ),
        conditionalPanel(
          condition = "input.tlg_tables == 'cmt01'",
          tlg_page_header("CMT01", "Concomitant Medications by Class and Preferred Name", "S13", cfg),
          DTOutput("cm_summary_tbl")
        )
      )
    )
  ),

  tabPanel(
    "Listings",
    tlg_catalog_page(
      "tlg_listings",
      "Listings",
      TLG_NAV$listings,
      tagList(
        conditionalPanel(
          condition = "input.tlg_listings == 'ael03'",
          tlg_page_header("AEL03", "Listing of Serious Adverse Events", "S4", cfg),
          DTOutput("sae_tbl")
        ),
        conditionalPanel(
          condition = "input.tlg_listings == 'cml01'",
          tlg_page_header("CML01", "Listing of Previous and Concomitant Medications", "S13", cfg),
          DTOutput("cm_listing_tbl")
        ),
        conditionalPanel(
          condition = "input.tlg_listings == 'exl01'",
          tlg_page_header("EXL01", "Listing of Exposure to Study Drug", "S11", cfg),
          DTOutput("exposure_detail_tbl_listing")
        )
      )
    )
  ),

  tabPanel(
    "Graphs",
    tlg_catalog_page(
      "tlg_graphs",
      "Graphs",
      TLG_NAV$graphs,
      tagList(
        conditionalPanel(
          condition = "input.tlg_graphs == 'lbt01'",
          tlg_page_header("LBT01", "Laboratory Results and Change from Baseline by Visit", "S6", cfg),
          div(class = "stf-note", "Graph analogue: LTG01 lattice plot."),
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
        conditionalPanel(
          condition = "input.tlg_graphs == 'lbt09'",
          tlg_page_header("LBT09", "Hepatic Safety / Hy's Law (eDISH)", "S8", cfg),
          div(class = "stf-note", "Related TLGs: LBT10 (consecutive elevations), LBT11 (time to Hy's Law)."),
          plotOutput("hys_plot", height = "500px"),
          br(),
          h4("Subjects in the Hy's Law zone"),
          DTOutput("hys_tbl")
        ),
        conditionalPanel(
          condition = "input.tlg_graphs == 'vst01'",
          tlg_page_header("VST01", "Vital Sign Results and Change from Baseline by Visit", "S12", cfg),
          selectInput("vs_param", "Vital sign parameter:",
                      choices = VS_PARAMS,
                      selected = if (length(VS_PARAMS) > 0) VS_PARAMS[1] else NULL),
          plotOutput("vs_plot", height = "460px")
        ),
        conditionalPanel(
          condition = "input.tlg_graphs == 'kmg01'",
          tlg_page_header("KMG01", "Kaplan-Meier Plot", "S10", cfg),
          div(class = "stf-note", "Summary table analogue: TTET01."),
          selectInput("tte_endpoint", "Time-to-event endpoint:",
                      choices = TTE_ENDPOINTS, selected = DEFAULT_TTE),
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
        conditionalPanel(
          condition = "input.tlg_graphs == 'aet02g'",
          tlg_page_header("AET02", "Top Treatment-Emergent AEs (incidence chart)", "S5", cfg),
          plotOutput("teae_plot", height = "460px")
        ),
        conditionalPanel(
          condition = "input.tlg_graphs == 'corr01'",
          tlg_page_header("Custom", "Safety Parameter Correlation", "S14", cfg),
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
  ),

  tabPanel(
    "Patient Profile",
    fluidRow(
      class = "tlg-shell",
      column(
        12,
        div(
          class = "tlg-main",
          tlg_page_header("IPPG01", "Individual Patient Plot Over Time", "S9", cfg),
          fluidRow(
            column(
              4,
              wellPanel(
                checkboxInput("pp_completed_only", "Completed trial only", value = FALSE),
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
          fluidRow(column(12, h4("Demographics"), DTOutput("pp_demo"))),
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
  output$exposure_detail_tbl_listing <- renderDT({
    dt(exposure_detail_table(ADEX, ADSL, cfg, selected_arms()))
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
